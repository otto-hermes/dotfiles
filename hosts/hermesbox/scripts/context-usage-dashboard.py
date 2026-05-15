#!/usr/bin/env python3
"""Tiny tailnet dashboard for Hermes prompt/context usage.

Shows the latest captured provider request dump plus static Hermes context files.
It intentionally reports sizes/counts only, not raw prompt text or secrets.
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import os
import re
import socket
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any

try:
    import tiktoken  # type: ignore
except Exception:  # pragma: no cover - fallback for emergency shell runs
    tiktoken = None

HERMES_HOME = Path(os.environ.get("HERMES_HOME", "/home/hermes/.hermes"))
SESSIONS = HERMES_HOME / "sessions"
DOTFILES = Path("/home/hermes/dotfiles")

if tiktoken:
    try:
        ENC = tiktoken.encoding_for_model("gpt-4o")
    except Exception:
        ENC = tiktoken.get_encoding("cl100k_base")
else:
    ENC = None


def token_count(value: Any) -> int:
    if value is None:
        text = ""
    elif isinstance(value, str):
        text = value
    else:
        text = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    if ENC is not None:
        return len(ENC.encode(text))
    # crude fallback: decent enough to keep the dashboard alive without tiktoken
    return max(1, round(len(text) / 4)) if text else 0


def byte_len(value: Any) -> int:
    if value is None:
        return 0
    if isinstance(value, str):
        text = value
    else:
        text = json.dumps(value, ensure_ascii=False, separators=(",", ":"))
    return len(text.encode("utf-8"))


def latest_request_dump() -> Path | None:
    if not SESSIONS.exists():
        return None
    dumps = list(SESSIONS.glob("request_dump_*.json"))
    if not dumps:
        return None
    return max(dumps, key=lambda p: p.stat().st_mtime)


def split_instructions(text: str) -> list[dict[str, Any]]:
    if not text:
        return []

    markers = [
        ("SOUL.md", r"(?m)^# SOUL\.md\s*$"),
        ("Tool-use / execution policy", r"(?m)^# Tool-use enforcement\s*$"),
        ("Available skills list", r"(?s)<available_skills>.*?</available_skills>"),
        ("Memory block", r"(?m)^═+\nMEMORY .*?\n═+\n"),
        ("User profile block", r"(?m)^═+\nUSER PROFILE .*?\n═+\n"),
        ("Current session context", r"(?m)^Conversation started:.*$"),
    ]

    # Build non-overlapping spans. Some markers are headers, not full blocks; use
    # next marker/header boundary below for a readable approximation.
    raw_points: list[tuple[int, str]] = []
    for name, pattern in markers:
        m = re.search(pattern, text)
        if m:
            raw_points.append((m.start(), name))
    raw_points.sort()

    if not raw_points:
        return [{"name": "instructions", "tokens": token_count(text), "bytes": byte_len(text)}]

    sections: list[dict[str, Any]] = []
    if raw_points[0][0] > 0:
        prefix = text[: raw_points[0][0]]
        sections.append({"name": "instructions prefix", "tokens": token_count(prefix), "bytes": byte_len(prefix)})

    for i, (start, name) in enumerate(raw_points):
        end = raw_points[i + 1][0] if i + 1 < len(raw_points) else len(text)
        chunk = text[start:end]
        sections.append({"name": name, "tokens": token_count(chunk), "bytes": byte_len(chunk)})

    # Add heading-level top offenders too. This makes SOUL/user/developer docs easier to see.
    headings = []
    matches = list(re.finditer(r"(?m)^(#{1,3})\s+(.+)$", text))
    for i, m in enumerate(matches):
        start = m.start()
        end = matches[i + 1].start() if i + 1 < len(matches) else len(text)
        chunk = text[start:end]
        toks = token_count(chunk)
        if toks >= 200:
            headings.append({"name": m.group(2)[:90], "tokens": toks, "bytes": byte_len(chunk)})
    headings.sort(key=lambda x: x["tokens"], reverse=True)

    return sections + [{"name": f"heading: {h['name']}", "tokens": h["tokens"], "bytes": h["bytes"]} for h in headings[:15]]


def tool_group(name: str) -> str:
    for prefix in [
        "browser_", "cronjob", "delegate_", "terminal", "process", "read_file", "write_file", "search_files", "patch",
        "skill_", "skills_", "memory", "session_search", "send_message", "todo", "vision_", "image_", "clarify", "execute_code",
    ]:
        if name == prefix or name.startswith(prefix):
            return prefix.rstrip("_")
    return name.split("_")[0] if "_" in name else name


def request_snapshot(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {"available": False, "error": "no request_dump_*.json found"}
    try:
        data = json.loads(path.read_text())
    except Exception as e:
        return {"available": False, "path": str(path), "error": str(e)}

    req = data.get("request", {})
    body = req.get("body", {}) if isinstance(req, dict) else {}
    instructions = body.get("instructions", "")
    inputs = body.get("input", [])
    tools = body.get("tools", []) or []

    instruction_tokens = token_count(instructions)
    input_tokens = token_count(inputs)
    tool_tokens = token_count(tools)
    total = instruction_tokens + input_tokens + tool_tokens

    tool_rows = []
    by_group: dict[str, dict[str, Any]] = {}
    for tool in tools:
        name = str(tool.get("name", "<unnamed>"))
        toks = token_count(tool)
        row = {"name": name, "group": tool_group(name), "tokens": toks, "bytes": byte_len(tool)}
        tool_rows.append(row)
        g = by_group.setdefault(row["group"], {"name": row["group"], "count": 0, "tokens": 0, "bytes": 0})
        g["count"] += 1
        g["tokens"] += row["tokens"]
        g["bytes"] += row["bytes"]

    tool_rows.sort(key=lambda x: x["tokens"], reverse=True)
    groups = sorted(by_group.values(), key=lambda x: x["tokens"], reverse=True)

    return {
        "available": True,
        "path": str(path),
        "mtime": dt.datetime.fromtimestamp(path.stat().st_mtime).isoformat(timespec="seconds"),
        "session_id": data.get("session_id"),
        "model": body.get("model"),
        "reason": data.get("reason"),
        "url_host": re.sub(r"^https?://", "", str(req.get("url", ""))).split("/")[0],
        "totals": {
            "instructions": instruction_tokens,
            "input": input_tokens,
            "tools": tool_tokens,
            "request_total": total,
            "tool_count": len(tools),
        },
        "instruction_sections": split_instructions(instructions),
        "tool_groups": groups,
        "tools_top": tool_rows[:30],
    }


def static_files_snapshot() -> list[dict[str, Any]]:
    candidates = [
        HERMES_HOME / "memories" / "MEMORY.md",
        HERMES_HOME / "config.yaml",
        DOTFILES / "hosts" / "hermesbox" / "hermes-agent.nix",
        DOTFILES / "hosts" / "hermesbox" / "configuration.nix",
    ]
    rows = []
    for p in candidates:
        try:
            text = p.read_text(errors="replace")
            rows.append({"path": str(p), "tokens": token_count(text), "bytes": byte_len(text)})
        except FileNotFoundError:
            rows.append({"path": str(p), "missing": True, "tokens": 0, "bytes": 0})
    # Installed skills: count manifest/descriptions and SKILL.md total, but do not dump contents.
    skills_dir = HERMES_HOME / "skills"
    skill_rows = []
    if skills_dir.exists():
        for skill in skills_dir.glob("**/SKILL.md"):
            try:
                text = skill.read_text(errors="replace")
            except Exception:
                continue
            skill_rows.append({"path": str(skill), "tokens": token_count(text), "bytes": byte_len(text)})
    skill_rows.sort(key=lambda x: x["tokens"], reverse=True)
    rows.append({
        "path": f"{skills_dir}/**/SKILL.md",
        "tokens": sum(r["tokens"] for r in skill_rows),
        "bytes": sum(r["bytes"] for r in skill_rows),
        "count": len(skill_rows),
        "top": skill_rows[:20],
    })
    return rows


def build_snapshot() -> dict[str, Any]:
    path = latest_request_dump()
    return {
        "generated_at": dt.datetime.now().isoformat(timespec="seconds"),
        "host": socket.gethostname(),
        "hermes_home": str(HERMES_HOME),
        "tokenizer": "tiktoken:gpt-4o" if ENC is not None else "approx chars/4 fallback",
        "latest_request": request_snapshot(path),
        "static_files": static_files_snapshot(),
    }


def pct(n: int, d: int) -> str:
    return "0%" if not d else f"{(100*n/d):.1f}%"


def bar(n: int, d: int) -> str:
    width = 32
    filled = 0 if not d else max(1, min(width, round(width * n / d)))
    return "█" * filled + "░" * (width - filled)


def render_table(rows: list[dict[str, Any]], total: int | None = None, name_key: str = "name") -> str:
    denom = total if total is not None else max([int(r.get("tokens", 0)) for r in rows] + [1])
    out = []
    for r in rows:
        name = html.escape(str(r.get(name_key, r.get("path", "?"))))
        toks = int(r.get("tokens", 0))
        meta = []
        if "count" in r:
            meta.append(f"count {r['count']}")
        if "bytes" in r:
            meta.append(f"{int(r['bytes'])/1024:.1f} KiB")
        out.append(f"""
        <div class=row>
          <div class=name title="{name}">{name}</div>
          <div class=bar>{bar(toks, denom)}</div>
          <div class=num>{toks:,}</div>
          <div class=pct>{pct(toks, denom)}</div>
          <div class=meta>{html.escape(' · '.join(meta))}</div>
        </div>""")
    return "\n".join(out)


def render_html(s: dict[str, Any]) -> bytes:
    req = s["latest_request"]
    if req.get("available"):
        totals = req["totals"]
        cards = f"""
          <div class=card><span>request total</span><b>{totals['request_total']:,}</b></div>
          <div class=card><span>instructions</span><b>{totals['instructions']:,}</b></div>
          <div class=card><span>tools</span><b>{totals['tools']:,}</b></div>
          <div class=card><span>input</span><b>{totals['input']:,}</b></div>
          <div class=card><span>tool schemas</span><b>{totals['tool_count']:,}</b></div>
        """
        request_meta = f"model {html.escape(str(req.get('model')))} · session {html.escape(str(req.get('session_id')))} · dump {html.escape(Path(req.get('path')).name)} · mtime {html.escape(str(req.get('mtime')))}"
        sections = render_table(req["instruction_sections"], totals["instructions"] or None)
        tool_groups = render_table(req["tool_groups"], totals["tools"] or None)
        tools_top = render_table(req["tools_top"], totals["tools"] or None)
    else:
        cards = f"<div class=card><span>error</span><b>{html.escape(str(req.get('error')))}</b></div>"
        request_meta = "No captured request dump found."
        sections = tool_groups = tools_top = ""

    static_rows = []
    for r in s["static_files"]:
        static_rows.append({"name": r["path"], "tokens": r.get("tokens", 0), "bytes": r.get("bytes", 0), "count": r.get("count", "")})
    static_total = max(sum(r.get("tokens", 0) for r in static_rows), 1)

    body = f"""<!doctype html>
<html>
<head>
  <meta charset=utf-8>
  <meta name=viewport content="width=device-width, initial-scale=1">
  <meta http-equiv=refresh content=20>
  <title>Hermes context usage</title>
  <style>
    :root {{ color-scheme: dark; --bg:#0b0f14; --panel:#111822; --muted:#8aa0b5; --text:#d7e1ea; --accent:#82aaff; --hot:#ffcb6b; }}
    body {{ margin:0; font:14px/1.35 ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; background:var(--bg); color:var(--text); }}
    main {{ max-width:1180px; margin:0 auto; padding:24px; }}
    h1 {{ font-size:22px; margin:0 0 6px; }}
    h2 {{ margin:28px 0 10px; font-size:16px; color:#c3ddff; }}
    .muted {{ color:var(--muted); }}
    .cards {{ display:grid; grid-template-columns: repeat(auto-fit,minmax(150px,1fr)); gap:12px; margin:18px 0; }}
    .card {{ background:var(--panel); border:1px solid #1e2a38; border-radius:12px; padding:14px; }}
    .card span {{ display:block; color:var(--muted); font-size:12px; }}
    .card b {{ display:block; font-size:24px; margin-top:5px; color:var(--hot); }}
    .table {{ background:var(--panel); border:1px solid #1e2a38; border-radius:12px; overflow:hidden; }}
    .row {{ display:grid; grid-template-columns:minmax(260px,1.4fr) 260px 110px 70px minmax(120px,.6fr); gap:12px; align-items:center; padding:8px 12px; border-top:1px solid #1b2633; }}
    .row:first-child {{ border-top:0; }}
    .name {{ white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }}
    .bar {{ color:var(--accent); letter-spacing:-1px; white-space:nowrap; }}
    .num {{ text-align:right; color:#fff; }}
    .pct,.meta {{ color:var(--muted); }}
    a {{ color:var(--accent); }}
    @media (max-width: 880px) {{ .row {{ grid-template-columns:1fr; gap:3px; }} .num {{ text-align:left; }} }}
  </style>
</head>
<body>
<main>
  <h1>Hermes context usage</h1>
  <div class=muted>Generated {html.escape(s['generated_at'])} on {html.escape(s['host'])} · {html.escape(s['tokenizer'])} · <a href="/api/snapshot">JSON</a></div>
  <div class=cards>{cards}</div>
  <div class=muted>{request_meta}</div>

  <h2>Latest provider request: instruction breakdown</h2>
  <div class=table>{sections}</div>

  <h2>Latest provider request: tool schema groups</h2>
  <div class=table>{tool_groups}</div>

  <h2>Latest provider request: largest individual tools</h2>
  <div class=table>{tools_top}</div>

  <h2>Static files / installed skill corpus</h2>
  <div class=table>{render_table(static_rows, static_total)}</div>

  <p class=muted>Note: this uses the latest Hermes request dump, so it reflects actual provider payload shape when dumps are present. It reports counts only, not prompt contents or secrets.</p>
</main>
</body>
</html>"""
    return body.encode("utf-8")


class Handler(BaseHTTPRequestHandler):
    def log_message(self, format: str, *args: Any) -> None:
        sys.stderr.write("%s - %s\n" % (self.address_string(), format % args))

    def do_GET(self) -> None:  # noqa: N802
        if self.path in ("/", "/index.html"):
            payload = render_html(build_snapshot())
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        if self.path == "/api/snapshot":
            payload = json.dumps(build_snapshot(), indent=2, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        self.send_error(404)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=9121)
    args = ap.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"context usage dashboard listening on http://{args.host}:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
