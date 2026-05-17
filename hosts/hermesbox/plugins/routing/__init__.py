"""Hermes routing plugin: first-class `route_task` tool.

The tool intentionally exposes a narrow argv-only interface over the existing
Nix-managed `hermes-profile-router`/profile wrappers. It avoids handing the
default profile broad shell execution just to route specialist work.
"""
from __future__ import annotations

import json
import os
import subprocess
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

TOOLSET = "routing"
TOOL_NAME = "route_task"
DEFAULT_CONFIDENCE_FLOOR = 0.35
DEFAULT_LAUNCH_TIMEOUT_SECONDS = 900
LOG_TAIL_CHARS = 8000
REFUSED_LAUNCH_PROFILES = {"default"}


def _hermes_home() -> Path:
    return Path(os.environ.get("HERMES_HOME") or "/home/hermes/.hermes")


def _router_bin() -> str:
    return os.environ.get("HERMES_PROFILE_ROUTER") or "/run/current-system/sw/bin/hermes-profile-router"


def _hermes_bin() -> str:
    return os.environ.get("HERMES_BIN") or "/run/current-system/sw/bin/hermes"


def _base_env() -> Dict[str, str]:
    env = os.environ.copy()
    env["HERMES_HOME"] = str(_hermes_home())
    env.setdefault("HOME", "/home/hermes")
    return env


def _json_result(payload: Dict[str, Any]) -> str:
    return json.dumps(payload, ensure_ascii=False, sort_keys=True)


def _parse_json(text: str, stage: str) -> Tuple[Optional[Dict[str, Any]], Optional[Dict[str, Any]]]:
    try:
        value = json.loads(text)
    except json.JSONDecodeError as exc:
        return None, {
            "ok": False,
            "status": "router_json_error",
            "stage": stage,
            "error": str(exc),
            "stdout_tail": text[-LOG_TAIL_CHARS:],
        }
    if not isinstance(value, dict):
        return None, {
            "ok": False,
            "status": "router_json_error",
            "stage": stage,
            "error": f"Expected JSON object, got {type(value).__name__}",
            "stdout_tail": text[-LOG_TAIL_CHARS:],
        }
    return value, None


def _run_router(action: str, task: str) -> Tuple[Optional[Dict[str, Any]], Optional[Dict[str, Any]]]:
    argv = [_router_bin(), action, "--json", task]
    try:
        proc = subprocess.run(
            argv,
            text=True,
            capture_output=True,
            timeout=60,
            env=_base_env(),
            shell=False,
        )
    except FileNotFoundError as exc:
        return None, {
            "ok": False,
            "status": "router_unavailable",
            "action": action,
            "error": str(exc),
            "router": argv[0],
        }
    except subprocess.TimeoutExpired as exc:
        return None, {
            "ok": False,
            "status": "router_timeout",
            "action": action,
            "error": str(exc),
            "router": argv[0],
        }

    if proc.returncode != 0:
        return None, {
            "ok": False,
            "status": "router_failed",
            "action": action,
            "exit_code": proc.returncode,
            "stdout_tail": proc.stdout[-LOG_TAIL_CHARS:],
            "stderr_tail": proc.stderr[-LOG_TAIL_CHARS:],
            "router": argv[0],
        }

    parsed, err = _parse_json(proc.stdout, action)
    if err:
        err["router"] = argv[0]
    return parsed, err


def _profiles_from_router() -> List[str]:
    argv = [_router_bin(), "list", "--json"]
    proc = subprocess.run(
        argv,
        text=True,
        capture_output=True,
        timeout=60,
        env=_base_env(),
        shell=False,
    )
    if proc.returncode != 0:
        return []
    try:
        value = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []
    profiles = []
    if isinstance(value, list):
        for item in value:
            if isinstance(item, dict) and isinstance(item.get("name"), str):
                profiles.append(item["name"])
            elif isinstance(item, str):
                profiles.append(item)
    return profiles


def _select_profile(task: str, explicit_profile: Optional[str]) -> Tuple[Optional[str], Dict[str, Any], Optional[Dict[str, Any]]]:
    if explicit_profile:
        available = set(_profiles_from_router())
        if explicit_profile in REFUSED_LAUNCH_PROFILES:
            return None, {}, {
                "ok": False,
                "status": "recursive_default_refused",
                "profile": explicit_profile,
                "reason": "route_task launch refuses to launch the default profile recursively.",
            }
        if explicit_profile not in available:
            return None, {"available_profiles": sorted(available)}, {
                "ok": False,
                "status": "profile_missing",
                "profile": explicit_profile,
                "available_profiles": sorted(available),
            }
        return explicit_profile, {"explicit_profile": True, "available_profiles": sorted(available)}, None

    choice, err = _run_router("choose", task)
    if err:
        return None, {}, err
    profile = choice.get("profile") if isinstance(choice, dict) else None
    if not isinstance(profile, str) or not profile:
        return None, {"choice": choice}, {
            "ok": False,
            "status": "profile_missing",
            "choice": choice,
            "reason": "router did not select a profile",
        }
    return profile, {"choice": choice}, None


def _confidence_from_choice(meta: Dict[str, Any]) -> float:
    choice = meta.get("choice") if isinstance(meta, dict) else None
    if isinstance(choice, dict):
        value = choice.get("confidence", 0.0)
        try:
            return float(value)
        except (TypeError, ValueError):
            return 0.0
    return 1.0 if meta.get("explicit_profile") else 0.0


def _log_path(profile: str) -> Path:
    log_dir = _hermes_home() / "logs" / "profile-router"
    log_dir.mkdir(parents=True, exist_ok=True)
    safe = "".join(ch if ch.isalnum() or ch in {"-", "_"} else "_" for ch in profile)
    return log_dir / f"route-task-{safe}-{int(time.time())}.log"


def _launch(task: str, profile: str, mode: str, timeout_seconds: int) -> Dict[str, Any]:
    argv = [_hermes_bin(), "--profile", profile, "-z", task]
    env = _base_env()
    env["HERMES_HOME"] = str(_hermes_home())

    if mode == "background":
        path = _log_path(profile)
        fh = path.open("ab")
        proc = subprocess.Popen(argv, stdout=fh, stderr=subprocess.STDOUT, env=env, shell=False)
        fh.close()
        return {
            "ok": True,
            "status": "launched_background",
            "profile": profile,
            "pid": proc.pid,
            "log_path": str(path),
            "argv": argv[:3] + ["-z", "<task>"],
        }

    try:
        proc = subprocess.run(
            argv,
            text=True,
            capture_output=True,
            timeout=timeout_seconds,
            env=env,
            shell=False,
        )
    except subprocess.TimeoutExpired as exc:
        return {
            "ok": False,
            "status": "launch_timeout",
            "profile": profile,
            "timeout_seconds": timeout_seconds,
            "error": str(exc),
            "stdout_tail": (exc.stdout or "")[-LOG_TAIL_CHARS:] if isinstance(exc.stdout, str) else "",
            "stderr_tail": (exc.stderr or "")[-LOG_TAIL_CHARS:] if isinstance(exc.stderr, str) else "",
        }
    except FileNotFoundError as exc:
        return {
            "ok": False,
            "status": "launcher_unavailable",
            "profile": profile,
            "error": str(exc),
            "hermes": argv[0],
        }

    return {
        "ok": proc.returncode == 0,
        "status": "completed" if proc.returncode == 0 else "launch_failed",
        "profile": profile,
        "exit_code": proc.returncode,
        "stdout": proc.stdout[-LOG_TAIL_CHARS:],
        "stderr_tail": proc.stderr[-LOG_TAIL_CHARS:],
        "argv": argv[:3] + ["-z", "<task>"],
    }


def route_task(args: Dict[str, Any], **_kwargs: Any) -> str:
    action = str(args.get("action", "")).strip().lower()
    task = str(args.get("task", "")).strip()
    explicit_profile = args.get("profile")
    if explicit_profile is not None:
        explicit_profile = str(explicit_profile).strip() or None
    mode = str(args.get("mode", "foreground")).strip().lower() or "foreground"
    try:
        floor = float(args.get("max_confidence_floor", DEFAULT_CONFIDENCE_FLOOR))
    except (TypeError, ValueError):
        floor = DEFAULT_CONFIDENCE_FLOOR
    try:
        timeout_seconds = int(args.get("timeout_seconds", DEFAULT_LAUNCH_TIMEOUT_SECONDS))
    except (TypeError, ValueError):
        timeout_seconds = DEFAULT_LAUNCH_TIMEOUT_SECONDS

    if action not in {"choose", "plan", "launch"}:
        return _json_result({"ok": False, "status": "invalid_action", "action": action})
    if not task:
        return _json_result({"ok": False, "status": "missing_task"})
    if mode not in {"foreground", "background"}:
        return _json_result({"ok": False, "status": "invalid_mode", "mode": mode})

    if action in {"choose", "plan"}:
        result, err = _run_router(action, task)
        if err:
            return _json_result(err)
        result = dict(result or {})
        result.setdefault("ok", True)
        result.setdefault("status", action)
        return _json_result(result)

    profile, meta, err = _select_profile(task, explicit_profile)
    if err:
        return _json_result(err)
    assert profile is not None
    if profile in REFUSED_LAUNCH_PROFILES:
        return _json_result({
            "ok": False,
            "status": "recursive_default_refused",
            "profile": profile,
            "route": meta,
        })

    confidence = _confidence_from_choice(meta)
    if explicit_profile is None and confidence < floor:
        return _json_result({
            "ok": False,
            "status": "low_confidence",
            "profile": profile,
            "confidence": confidence,
            "confidence_floor": floor,
            "route": meta,
            "reason": "Refusing automatic launch below confidence floor; use choose/plan or explicit profile override.",
        })

    launch_result = _launch(task, profile, mode, timeout_seconds)
    launch_result["route"] = meta
    launch_result["confidence"] = confidence
    return _json_result(launch_result)


ROUTE_TASK_SCHEMA = {
    "name": TOOL_NAME,
    "description": (
        "Choose, plan, or launch a Hermes specialist profile for a task using "
        "declarative profile metadata. This is a narrow routing interface, not "
        "a general shell. Use choose/plan for classification and launch for "
        "specialist execution. Launch refuses default recursion and low-confidence "
        "automatic fallback unless an explicit profile is supplied."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "action": {"type": "string", "enum": ["choose", "plan", "launch"]},
            "task": {"type": "string", "minLength": 1},
            "profile": {
                "type": "string",
                "description": "Optional explicit specialist profile for launch; must exist and must not be default.",
            },
            "mode": {"type": "string", "enum": ["foreground", "background"], "default": "foreground"},
            "max_confidence_floor": {"type": "number", "default": DEFAULT_CONFIDENCE_FLOOR},
            "timeout_seconds": {"type": "integer", "default": DEFAULT_LAUNCH_TIMEOUT_SECONDS},
        },
        "required": ["action", "task"],
    },
}


def register(ctx: Any) -> None:
    ctx.register_tool(
        name=TOOL_NAME,
        toolset=TOOLSET,
        schema=ROUTE_TASK_SCHEMA,
        handler=route_task,
        description=ROUTE_TASK_SCHEMA["description"],
        emoji="🧭",
    )
