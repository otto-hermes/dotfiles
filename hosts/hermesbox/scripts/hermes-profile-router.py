#!/usr/bin/env python3
"""Route Hermes work to a suitable named profile.

Reads dynamic profile metadata from ~/.hermes/profiles/*/PROFILE.md frontmatter.
This script deliberately does not hardcode profile names; Nix generates the
frontmatter next to each declarative profile.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import sys
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any

HERMES_HOME = Path(os.environ.get("HERMES_HOME") or Path.home() / ".hermes")
PROFILES_DIR = HERMES_HOME / "profiles"
HERMES_BIN = os.environ.get("HERMES_BIN", "/run/current-system/sw/bin/hermes")


@dataclass
class Profile:
    name: str
    summary: str = ""
    tags: list[str] | None = None
    use_for: list[str] | None = None
    avoid_for: list[str] | None = None
    fallback: bool = False
    priority: int = 50

    def haystack(self) -> str:
        parts: list[str] = [self.name, self.summary]
        for xs in (self.tags or [], self.use_for or []):
            parts.append(str(xs))
        return "\n".join(parts).lower()


def parse_scalar(value: str) -> Any:
    value = value.strip()
    if not value:
        return ""
    if value in {"true", "false"}:
        return value == "true"
    if re.fullmatch(r"-?\d+", value):
        return int(value)
    if value.startswith('"') and value.endswith('"'):
        try:
            return json.loads(value)
        except Exception:
            return value[1:-1]
    if value.startswith("[") and value.endswith("]"):
        try:
            return json.loads(value)
        except Exception:
            return [x.strip().strip('"') for x in value[1:-1].split(",") if x.strip()]
    return value


def parse_frontmatter(path: Path) -> dict[str, Any]:
    text = path.read_text(errors="replace")
    m = re.match(r"^---\s*\n(.*?)\n---\s*(?:\n|$)", text, re.S)
    if not m:
        return {}
    data: dict[str, Any] = {}
    current_key: str | None = None
    for raw in m.group(1).splitlines():
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if line.startswith("  - ") and current_key:
            data.setdefault(current_key, []).append(parse_scalar(line[4:]))
            continue
        if ":" in line and not line.startswith(" "):
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip()
            current_key = key
            if value == "":
                data[key] = []
            else:
                data[key] = parse_scalar(value)
    return data


def load_profiles() -> list[Profile]:
    profiles: list[Profile] = []
    if not PROFILES_DIR.exists():
        return profiles
    for profile_dir in sorted(p for p in PROFILES_DIR.iterdir() if p.is_dir()):
        doc = profile_dir / "PROFILE.md"
        if not doc.exists():
            continue
        fm = parse_frontmatter(doc)
        name = str(fm.get("name") or profile_dir.name)
        profiles.append(Profile(
            name=name,
            summary=str(fm.get("summary") or ""),
            tags=list(fm.get("tags") or []),
            use_for=list(fm.get("use_for") or []),
            avoid_for=list(fm.get("avoid_for") or []),
            fallback=bool(fm.get("fallback") or False),
            priority=int(fm.get("priority") or 50),
        ))
    return profiles


def tokenize(text: str, *, expand_aliases: bool = True) -> set[str]:
    stopwords = {
        "the", "and", "for", "with", "this", "that", "into", "from", "about", "what",
        "should", "would", "could", "please", "make", "create", "thing", "stuff", "using",
        "need", "want", "have", "does", "done", "your", "user", "task", "work",
    }
    words = {
        w for w in re.findall(r"[a-z0-9][a-z0-9_+.-]{2,}", text.lower())
        if w not in stopwords
    }
    if not expand_aliases:
        return words

    aliases = {
        "code": ["coding", "programming", "bug", "debug", "debugging", "fix", "failing", "failure", "test", "tests", "pytest", "python", "repo", "github", "pr"],
        "media": ["image", "video", "audio", "tts", "song", "music", "gif", "poster", "visual"],
        "research": ["search", "web", "compare", "lookup", "current", "news", "papers"],
        "knowledge": ["wiki", "memory", "obsidian", "notes", "curate", "curation", "index", "summarize"],
        "sysadmin": ["nixos", "service", "systemd", "config", "disk", "process", "port"],
        "simple": ["quick", "small", "trivial", "one-line", "rename", "check"],
    }
    expanded = set(words)
    for key, vals in aliases.items():
        if key in words:
            expanded.update(vals)
        elif any(v in words for v in vals):
            # Add only the category, not every sibling synonym. Expanding
            # "wiki" into "memory notes index summarize" made broad profiles
            # swamp narrow scheduled profiles like wiki-linter/session-indexer.
            expanded.add(key)
    return expanded


def decision_for(profile: str, confidence: float, reason: str) -> dict[str, Any]:
    return {
        "profile": profile,
        "confidence": confidence,
        "score": 0.0,
        "margin": 0.0,
        "reason": reason,
        "candidates": [],
    }


def first_available(profiles: list[Profile], names: list[str], default: str = "default") -> str:
    available = {p.name for p in profiles}
    for name in names:
        if name == "default" or name in available:
            return name
    return default


def matches_any(msg: str, patterns: list[str]) -> bool:
    return any(re.search(pattern, msg) for pattern in patterns)


def guardrail_decision(message: str, profiles: list[Profile]) -> dict[str, Any] | None:
    """Hard routing rules for high-signal domains before generic scoring."""
    msg = message.lower()

    mutation = matches_any(msg, [
        r"\b(edit|configure|config(?:ure)?|change|modify|patch|update|add|remove|delete|fix|implement|refactor|build|write|create|install|enable|disable|switch|rebuild|deploy)\b",
    ])
    code_domain = matches_any(msg, [
        r"\b(code|coding|software|debug|bug|test|tests|pytest|repo|repository|git|github|pr|pull request|branch|commit)\b",
    ])
    hermes_config_domain = matches_any(msg, [
        r"\b(nixos|nix|dotfiles?|flake|home-manager|hermes(?: agent)?|provider|providers|toolset|toolsets|profile|profiles|router|routing|cron|cronjob|gateway)\b",
    ])
    config_mutation_domain = code_domain or hermes_config_domain or (
        mutation and matches_any(msg, [r"\b(systemd|service|package|packages?)\b"])
    )
    code_or_config_domain = code_domain or hermes_config_domain

    chat_only = matches_any(msg, [
        r"\b(chat only|just chat|conversation only|no tools|don['’]?t do anything|do not do anything)\b",
        r"\bwhat do you think\b",
        r"\b(opinion|thoughts?|take|advice|recommendation)\b",
    ]) and not mutation
    if chat_only or ("chat only" in msg and not (mutation and code_or_config_domain)):
        return decision_for("default", 0.95, "guardrail: chat/opinion only stays on default")

    if matches_any(msg, [
        r"\b(implementation plan|careful plan|write (?:a )?plan|planning|architecture|architectural|decomposition|decompose|task breakdown|break down|roadmap)\b",
    ]):
        return decision_for(first_available(profiles, ["planner", "default"]), 0.9, "guardrail: planning/architecture/decomposition")

    if mutation and config_mutation_domain:
        return decision_for(first_available(profiles, ["codex-worker"]), 0.95, "guardrail: coding/NixOS/Hermes config mutation")

    if hermes_config_domain and matches_any(msg, [
        r"\b(check|inspect|review|audit|validate|verify|make sure|up to snuff|look at)\b",
    ]):
        return decision_for(first_available(profiles, ["codex-worker"]), 0.9, "guardrail: NixOS/Hermes/profile/router review")

    if matches_any(msg, [r"\b(session|sessions|transcript|transcripts)\b.*\b(index|summar|summary|summaries)", r"\bindex .*session"]):
        return decision_for(first_available(profiles, ["session-indexer", "knowledge-curator"]), 0.92, "guardrail: session indexing/summarization")

    if matches_any(msg, [r"\bwiki\b.*\b(lint|scan|contradiction|hygiene)", r"\b(lint|scan).*\bwiki\b"]):
        return decision_for(first_available(profiles, ["wiki-linter", "knowledge-curator"]), 0.92, "guardrail: wiki lint/scan")

    if matches_any(msg, [
        r"\b(wiki|memory|knowledge|obsidian|notes?|curat(?:e|ion)|knowledge[- ]base|session summar|session logs?)\b",
    ]):
        return decision_for(first_available(profiles, ["knowledge-curator"]), 0.88, "guardrail: knowledge/wiki/memory/session")

    if matches_any(msg, [
        r"\b(web research|research|look up|lookup|search (?:the )?web|current|latest|news|papers?|arxiv|polymarket|market|domain reconnaissance|competitive|competitor)\b",
    ]):
        return decision_for(first_available(profiles, ["research-worker"]), 0.9, "guardrail: web/current facts/research")

    if matches_any(msg, [
        r"\b(email|gmail|calendar|meeting|docs?|document|sheets?|spreadsheet|notion|airtable|linear|pdf|report|reporting)\b",
        r"\bsend\b.*\breport\b",
    ]):
        return decision_for(first_available(profiles, ["productivity-worker"]), 0.9, "guardrail: productivity/email/docs/reporting")

    if matches_any(msg, [
        r"\b(media|image|video|audio|tts|voice|vision|screenshot|design|diagram|poster|thumbnail|gif|music|song|visual)\b",
    ]):
        return decision_for(first_available(profiles, ["media-worker"]), 0.9, "guardrail: media/creative/vision")

    local_read = matches_any(msg, [
        r"\b(check|inspect|show|summarize|summarise|status|list|read|tail|look at|what is listening|listening)\b",
    ]) and matches_any(msg, [
        r"\b(port|ports|process|processes|disk|memory|cpu|service|systemctl|journal|logs?|file|files|directory|directories)\b",
    ])
    if local_read and not (mutation and code_or_config_domain):
        return decision_for(first_available(profiles, ["worker"]), 0.88, "guardrail: cheap local read/status check")

    return None


def choose(message: str, profiles: list[Profile]) -> dict[str, Any]:
    guardrail = guardrail_decision(message, profiles)
    if guardrail is not None:
        return guardrail

    msg = message.lower()
    msg_tokens = tokenize(message)
    scored: list[tuple[float, Profile, list[str]]] = []
    for p in profiles:
        score = p.priority / 100.0
        reasons: list[str] = []
        hay = p.haystack()
        profile_tokens = tokenize(hay, expand_aliases=False)
        overlap = sorted(msg_tokens & profile_tokens)
        if overlap:
            score += min(len(overlap), 12) * 0.8
            reasons.extend(f"keyword:{w}" for w in overlap[:8])
        for phrase in p.use_for or []:
            phrase_l = phrase.lower()
            phrase_tokens = tokenize(phrase_l)
            if phrase_l and phrase_l in msg:
                score += 4.0
                reasons.append(f"phrase:{phrase[:60]}")
            elif phrase_tokens and len(phrase_tokens & msg_tokens) >= min(3, len(phrase_tokens)):
                score += 1.8
                reasons.append(f"semantic:{phrase[:60]}")
        for phrase in p.avoid_for or []:
            phrase_l = phrase.lower()
            if phrase_l and phrase_l in msg:
                score -= 5.0
                reasons.append(f"avoid:{phrase[:60]}")
        scored.append((score, p, reasons))

    scored.sort(key=lambda x: x[0], reverse=True)
    if not scored:
        return {"profile": "default", "confidence": 0.0, "reason": "no profile metadata found", "candidates": []}

    best_score, best, reasons = scored[0]
    second_score = scored[1][0] if len(scored) > 1 else 0.0
    margin = best_score - second_score
    confidence = max(0.0, min(1.0, (best_score - 0.5) / 8.0))
    if margin < 0.75:
        confidence *= 0.65

    # If there is effectively no lexical evidence, prefer an explicit fallback
    # profile that can still get work done. Do not override a low-confidence but
    # clearly relevant specialist: short requests like "make a video" naturally
    # have only one or two strong keywords.
    if confidence < 0.35 and (not reasons or best_score < 2.0):
        fallback_name = fallback_profile(profiles)
        fallback_matches = [p for p in profiles if p.name == fallback_name]
        if fallback_matches:
            best = fallback_matches[0]
            reasons = ["low-confidence: using fallback profile"]
            confidence = 0.25

    return {
        "profile": best.name,
        "confidence": round(confidence, 2),
        "score": round(best_score, 2),
        "margin": round(margin, 2),
        "reason": "; ".join(reasons[:8]) or "highest routing score",
        "candidates": [
            {"profile": p.name, "score": round(score, 2), "reasons": rs[:5]}
            for score, p, rs in scored[:5]
        ],
    }


def has_profile(profiles: list[Profile], name: str) -> bool:
    return any(p.name == name for p in profiles)


def fallback_profile(profiles: list[Profile]) -> str:
    fallbacks = sorted([p for p in profiles if p.fallback], key=lambda p: p.priority, reverse=True)
    if fallbacks:
        return fallbacks[0].name
    return profiles[0].name if profiles else "default"


def non_worker_decision(message: str, profiles: list[Profile]) -> dict[str, Any]:
    non_worker = [p for p in profiles if p.name != "worker"]
    return choose(message, non_worker or profiles)


def looks_conditional(message: str) -> bool:
    msg = message.lower()
    has_check = bool(re.search(r"\b(check|look|find|search|see|verify)\b", msg))
    has_condition = bool(re.search(r"\b(if not|if missing|unless|otherwise|if absent|doesn['’]?t exist|do not exist|not found)\b", msg))
    has_make = bool(re.search(r"\b(create|make|generate|add|build|produce|write)\b", msg))
    return has_check and has_condition and has_make


def plan(message: str, profiles: list[Profile]) -> dict[str, Any]:
    """Return an executable routing plan for a user request.

    Atomic work gets one specialist step. Conditional "check then create" work gets a
    cheap worker check followed by the best non-worker specialist only when missing.
    """
    if not profiles:
        return {
            "strategy": "atomic",
            "reason": "no profile metadata found",
            "steps": [{"id": "do-task", "profile": "default", "task": message}],
            "fallback_profile": "default",
        }

    if looks_conditional(message) and has_profile(profiles, "worker"):
        create_decision = non_worker_decision(message, profiles)
        specialist = create_decision["profile"]
        if specialist == "worker":
            specialist = fallback_profile(profiles)
        return {
            "strategy": "conditional",
            "reason": "detected check-if-missing conditional workflow",
            "fallback_profile": fallback_profile(profiles),
            "steps": [
                {
                    "id": "check-existing",
                    "profile": "worker",
                    "task": (
                        "Check whether the requested artifact/state already exists. "
                        "Do not create, generate, modify, or delete anything. "
                        "Return a concise result starting with exactly FOUND or NOT_FOUND, "
                        "then include exact paths/evidence if found.\n\n"
                        f"Original user request:\n{message}"
                    ),
                },
                {
                    "id": "create-if-missing",
                    "profile": specialist,
                    "condition": "only if check-existing reports not found",
                    "task": (
                        "Only create or modify things if the previous check reported NOT_FOUND. "
                        "Complete the creation part of the original request, verify the result, "
                        "and report exact files/commands/handles.\n\n"
                        f"Original user request:\n{message}"
                    ),
                    "chosen_by": create_decision,
                },
            ],
        }

    decision = choose(message, profiles)
    return {
        "strategy": "atomic",
        "reason": "single-profile request",
        "fallback_profile": fallback_profile(profiles),
        "decision": decision,
        "steps": [
            {
                "id": "do-task",
                "profile": decision["profile"],
                "task": message,
                "chosen_by": decision,
            }
        ],
    }


def command_for(profile: str, message: str, background: bool = False) -> list[str]:
    prompt = (
        "You are a specialist Hermes worker profile. Complete the user's task directly. "
        "If you make external changes, verify them and summarize exact files/commands/handles.\n\n"
        f"User task:\n{message}"
    )
    return [HERMES_BIN, "--profile", profile, "chat", "-q", prompt]


def command_for_step(step: dict[str, Any]) -> list[str]:
    return command_for(str(step["profile"]), str(step["task"]))


def run_plan(route_plan: dict[str, Any]) -> int:
    """Run a route plan sequentially, evaluating simple NOT_FOUND conditions."""
    previous_output = ""
    for step in route_plan.get("steps", []):
        condition = str(step.get("condition") or "")
        if condition:
            normalized = previous_output.upper()
            if "NOT_FOUND" not in normalized and "NOT FOUND" not in normalized:
                print(json.dumps({"skipped": step["id"], "reason": condition}, indent=2))
                continue
        cmd = command_for_step(step)
        print(json.dumps({"running": step["id"], "profile": step["profile"], "command": cmd}, indent=2), file=sys.stderr)
        proc = subprocess.run(cmd, text=True, capture_output=True)
        if proc.stdout:
            print(proc.stdout, end="")
        if proc.stderr:
            print(proc.stderr, end="", file=sys.stderr)
        previous_output = proc.stdout + proc.stderr
        if proc.returncode != 0:
            return proc.returncode
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Route work to Hermes profiles using dynamic PROFILE.md frontmatter")
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    p_choose = sub.add_parser("choose")
    p_choose.add_argument("message", nargs="+")
    p_choose.add_argument("--json", action="store_true")
    p_cmd = sub.add_parser("command")
    p_cmd.add_argument("message", nargs="+")
    p_plan = sub.add_parser("plan")
    p_plan.add_argument("message", nargs="+")
    p_plan.add_argument("--json", action="store_true")
    p_plan.add_argument("--commands", action="store_true", help="Print shell commands for each planned step")
    p_execute = sub.add_parser("execute-plan")
    p_execute.add_argument("message", nargs="+")
    p_launch = sub.add_parser("launch")
    p_launch.add_argument("message", nargs="+")
    p_launch.add_argument("--background", action="store_true")
    args = ap.parse_args()

    profiles = load_profiles()

    if args.cmd == "list":
        print(json.dumps([asdict(p) for p in profiles], indent=2))
        return 0

    message = " ".join(getattr(args, "message", []))
    decision = choose(message, profiles)

    if args.cmd == "choose":
        if args.json:
            print(json.dumps(decision, indent=2))
        else:
            print(f"{decision['profile']} confidence={decision['confidence']} reason={decision['reason']}")
        return 0

    if args.cmd == "plan":
        route_plan = plan(message, profiles)
        if args.commands:
            for step in route_plan.get("steps", []):
                condition = step.get("condition")
                prefix = f"# {condition}\n" if condition else ""
                print(prefix + " ".join(shlex.quote(x) for x in command_for_step(step)))
        elif args.json:
            print(json.dumps(route_plan, indent=2))
        else:
            print(f"{route_plan['strategy']}: {route_plan['reason']}")
            for idx, step in enumerate(route_plan.get("steps", []), start=1):
                condition = f" ({step['condition']})" if step.get("condition") else ""
                print(f"{idx}. {step['id']} -> {step['profile']}{condition}")
        return 0

    if args.cmd == "execute-plan":
        route_plan = plan(message, profiles)
        print(json.dumps(route_plan, indent=2), file=sys.stderr)
        return run_plan(route_plan)

    cmd = command_for(decision["profile"], message)
    if args.cmd == "command":
        print(" ".join(shlex.quote(x) for x in cmd))
        return 0

    if args.cmd == "launch":
        if args.background:
            log_dir = HERMES_HOME / "logs" / "profile-router"
            log_dir.mkdir(parents=True, exist_ok=True)
            safe = re.sub(r"[^a-zA-Z0-9_.-]+", "-", decision["profile"]).strip("-")
            log_path = log_dir / f"{safe}-{os.getpid()}.log"
            with log_path.open("w") as log:
                proc = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            print(json.dumps({**decision, "pid": proc.pid, "log": str(log_path), "command": cmd}, indent=2))
        else:
            print(json.dumps(decision, indent=2), file=sys.stderr)
            return subprocess.call(cmd)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
