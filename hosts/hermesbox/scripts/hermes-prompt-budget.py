#!/usr/bin/env python3
"""Measure Hermes pre-user prompt and tool-schema token budget.

Read-only by design: instantiates Hermes Agent enough to render the system prompt
parts and discover active tool schemas, then reports token counts. Intended for
before/after measurement while cutting baseline token/cost overhead.
"""

from __future__ import annotations

import argparse
import contextlib
import io
import json
import os
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path
from typing import Any


def _load_tiktoken():
    try:
        import tiktoken  # type: ignore
        return tiktoken.get_encoding("cl100k_base")
    except Exception:
        return None


_ENCODING = _load_tiktoken()


def token_count(text: str) -> int:
    if not text:
        return 0
    if _ENCODING is not None:
        return len(_ENCODING.encode(text))
    # Conservative-ish fallback for environments without tiktoken. The wrapper
    # on hermesbox should provide tiktoken, so seeing this means the script is
    # still useful but less exact.
    return max(1, (len(text) + 3) // 4)


def json_tokens(obj: Any) -> int:
    return token_count(json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False))


def quiet_call(fn, *args, **kwargs):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
        return fn(*args, **kwargs)


def resolve_platform_toolsets(config: dict[str, Any], platform: str) -> list[str] | None:
    if platform == "cli":
        return config.get("toolsets")
    platform_toolsets = config.get("platform_toolsets") or {}
    value = platform_toolsets.get(platform)
    if value is None:
        value = config.get("toolsets")
    return value


def import_hermes_modules():
    try:
        from hermes_cli.config import load_config  # type: ignore
        from model_tools import get_tool_definitions, get_toolset_for_tool  # type: ignore
        from run_agent import AIAgent  # type: ignore
    except Exception as exc:  # pragma: no cover - user-facing diagnostic
        raise SystemExit(
            "Could not import Hermes modules. Run via the Nix wrapper or set "
            "PYTHONPATH to Hermes Agent site-packages. Original error: " + repr(exc)
        )
    return load_config, get_tool_definitions, get_toolset_for_tool, AIAgent


def analyze_platform(platform: str, *, include_context_files: bool) -> dict[str, Any]:
    load_config, get_tool_definitions, get_toolset_for_tool, AIAgent = import_hermes_modules()
    config = quiet_call(load_config)
    model_cfg = config.get("model") or {}
    enabled_toolsets = resolve_platform_toolsets(config, platform)

    agent = quiet_call(
        AIAgent,
        provider=model_cfg.get("provider"),
        model=model_cfg.get("default") or "",
        enabled_toolsets=enabled_toolsets,
        platform=platform,
        skip_context_files=not include_context_files,
        load_soul_identity=True,
        skip_memory=False,
        quiet_mode=True,
    )

    parts = quiet_call(agent._build_system_prompt_parts)
    full_system_prompt = "\n\n".join(v for v in parts.values() if v)

    tool_defs = quiet_call(get_tool_definitions, enabled_toolsets=enabled_toolsets, quiet_mode=True)
    tools_by_name: dict[str, dict[str, Any]] = {}
    for tool_def in tool_defs:
        fn = tool_def.get("function") or {}
        name = fn.get("name") or tool_def.get("name") or "<unknown>"
        tools_by_name[name] = tool_def

    per_tool = []
    per_toolset: dict[str, int] = defaultdict(int)
    for name, schema in sorted(tools_by_name.items()):
        n = json_tokens(schema)
        toolset = quiet_call(get_toolset_for_tool, name) or "<unknown>"
        per_tool.append({"name": name, "toolset": toolset, "tokens": n})
        per_toolset[toolset] += n

    # Split the stable prompt enough to identify the big levers without relying
    # on private internals beyond the actual assembled prompt parts.
    component_tokens = {
        "system_stable_identity_guidance_skills": token_count(parts.get("stable", "")),
        "context_files": token_count(parts.get("context", "")),
        "memory_user_timestamp": token_count(parts.get("volatile", "")),
        "tool_schemas": sum(item["tokens"] for item in per_tool),
    }
    component_tokens["total_pre_user_input"] = sum(component_tokens.values())

    return {
        "platform": platform,
        "model": model_cfg.get("default"),
        "provider": model_cfg.get("provider"),
        "tokenizer": "tiktoken:cl100k_base" if _ENCODING is not None else "chars/4 fallback",
        "include_context_files": include_context_files,
        "enabled_toolsets_configured": enabled_toolsets or [],
        "valid_tool_count": len(getattr(agent, "valid_tool_names", []) or []),
        "tool_schema_count": len(tools_by_name),
        "component_tokens": component_tokens,
        "top_tools": sorted(per_tool, key=lambda x: x["tokens"], reverse=True)[:20],
        "toolset_tokens": dict(sorted(per_toolset.items(), key=lambda kv: kv[1], reverse=True)),
    }


def format_report(results: list[dict[str, Any]], *, input_price_per_mtok: float | None) -> str:
    lines: list[str] = []
    lines.append("# Hermes Prompt Budget Report")
    lines.append("")
    lines.append(f"Generated: {datetime.now().isoformat(timespec='seconds')}")
    lines.append("")
    lines.append("Read-only measurement. Counts are pre-user input: rendered system prompt parts plus active tool schemas.")
    lines.append("")

    for result in results:
        comp = result["component_tokens"]
        lines.append(f"## {result['platform']}")
        lines.append("")
        lines.append(f"Model: `{result.get('provider')}/{result.get('model')}`")
        lines.append(f"Tokenizer: `{result['tokenizer']}`")
        lines.append(f"Configured toolsets: {len(result['enabled_toolsets_configured'])}")
        lines.append(f"Loaded tool schemas: {result['tool_schema_count']}")
        lines.append("")
        lines.append("### Component tokens")
        lines.append("")
        for key in ["system_stable_identity_guidance_skills", "context_files", "memory_user_timestamp", "tool_schemas", "total_pre_user_input"]:
            lines.append(f"- {key}: **{comp[key]:,}**")
        if input_price_per_mtok is not None:
            cost = comp["total_pre_user_input"] / 1_000_000 * input_price_per_mtok
            lines.append(f"- estimated baseline input cost/request at ${input_price_per_mtok:g}/M input tokens: **${cost:.6f}**")
        lines.append("")
        lines.append("### Toolset schema tokens")
        lines.append("")
        for toolset, count in list(result["toolset_tokens"].items())[:20]:
            lines.append(f"- {toolset}: {count:,}")
        lines.append("")
        lines.append("### Top tool schemas")
        lines.append("")
        for item in result["top_tools"][:20]:
            lines.append(f"- {item['name']} ({item['toolset']}): {item['tokens']:,}")
        lines.append("")

    if len(results) >= 2:
        base = results[0]["component_tokens"]["total_pre_user_input"]
        lines.append("## Cross-platform comparison")
        lines.append("")
        for result in results[1:]:
            total = result["component_tokens"]["total_pre_user_input"]
            delta = total - base
            pct = (delta / base * 100) if base else 0
            lines.append(f"- {result['platform']} vs {results[0]['platform']}: {delta:+,} tokens ({pct:+.1f}%)")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", action="append", default=None, help="Platform/profile entrypoint to measure. Repeatable. Defaults: cli, telegram, cron")
    parser.add_argument("--include-context-files", action="store_true", help="Include cwd AGENTS.md/CLAUDE.md/.cursorrules context files. Default false for stable baseline.")
    parser.add_argument("--json", action="store_true", help="Emit machine-readable JSON instead of Markdown.")
    parser.add_argument("--input-price-per-mtok", type=float, default=None, help="Optional model input price in dollars per million tokens for cost estimate.")
    args = parser.parse_args()

    os.environ.setdefault("HOME", "/home/hermes")
    os.environ.setdefault("HERMES_HOME", "/home/hermes/.hermes")

    platforms = args.platform or ["cli", "telegram", "cron"]
    results = [analyze_platform(p, include_context_files=args.include_context_files) for p in platforms]

    if args.json:
        print(json.dumps({"results": results}, indent=2, sort_keys=True))
    else:
        print(format_report(results, input_price_per_mtok=args.input_price_per_mtok))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
