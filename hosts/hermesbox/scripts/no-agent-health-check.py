#!/usr/bin/env python3
"""Deterministic no-agent health watchdog for Otto.

Default watchdog mode prints only actionable alerts; --summary prints a concise
context report for manual/test runs. Output deliberately avoids raw Hermes status
or job prompts so secrets cannot leak through local delivery or GitHub sync.
"""
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

mode = "summary" if len(sys.argv) > 1 and sys.argv[1] == "--summary" else "watchdog"
alerts: list[str] = []
notes: list[str] = []


def run(cmd: list[str], timeout: int = 10) -> tuple[int, str, str]:
    try:
        cp = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout)
        return cp.returncode, cp.stdout.strip(), cp.stderr.strip()
    except Exception as exc:
        return 127, "", str(exc)


# Disk/free-space summary.
for path_s in ["/", "/home", "/home/hermes"]:
    path = Path(path_s)
    if not path.exists():
        alerts.append(f"missing path: {path_s}")
        continue
    usage = shutil.disk_usage(path_s)
    free_gib = usage.free / (1024 ** 3)
    used_pct = usage.used / usage.total * 100 if usage.total else 0
    notes.append(f"disk {path_s}: {free_gib:.1f} GiB free, {used_pct:.0f}% used")
    if free_gib < 5 or used_pct >= 90:
        alerts.append(f"disk pressure on {path_s}: {free_gib:.1f} GiB free, {used_pct:.0f}% used")

# Gateway/systemd status; no raw journal/status dumps.
for svc in ["hermes-agent.service", "hermes-dashboard.service"]:
    rc, out, err = run(["systemctl", "is-active", svc], timeout=8)
    state = out or err or f"exit {rc}"
    notes.append(f"systemd {svc}: {state}")
    if rc != 0 or state != "active":
        alerts.append(f"systemd service not active: {svc} ({state})")

# Safe cron inventory: metadata only, no prompts/secrets.
jobs_path = Path("/home/hermes/.hermes/cron/jobs.json")
try:
    data = json.loads(jobs_path.read_text())
    jobs = [j for j in data.get("jobs", []) if isinstance(j, dict)]
    active = [j for j in jobs if j.get("enabled", True) and j.get("state") != "paused"]
    inventory = ", ".join(f"{j.get('name') or j.get('id')}={j.get('last_status') or 'unknown'}" for j in active[:8])
    notes.append(f"cron inventory: {inventory or 'no active jobs'}")
    if not active:
        alerts.append("cron inventory has no active jobs")
    for j in active:
        if j.get("last_status") in {"error", "failed"}:
            alerts.append(f"cron job last failed: {j.get('name') or j.get('id')}")
except Exception as exc:
    alerts.append(f"cannot read safe cron inventory: {exc}")

# Local Git mirror status only; no network or remote auth.
for repo_s in ["/home/hermes/dotfiles", "/home/hermes/hermes-brain-sync"]:
    repo = Path(repo_s)
    if not (repo / ".git").exists():
        alerts.append(f"git repo missing: {repo_s}")
        continue
    rc, out, err = run(["git", "-C", repo_s, "status", "--short"], timeout=10)
    if rc != 0:
        alerts.append(f"git status failed for {repo_s}: {err or out or rc}")
        continue
    changed = [line for line in out.splitlines() if line.strip()]
    notes.append(f"git {repo_s}: {len(changed)} local change(s)")
    if repo_s.endswith("hermes-brain-sync") and changed:
        alerts.append(f"brain mirror has {len(changed)} uncommitted local change(s)")

if mode == "summary":
    stamp = datetime.now(timezone.utc).astimezone().isoformat(timespec="seconds")
    print(f"Otto no-agent health summary @ {stamp}")
    if notes:
        print("OK/context:")
        for note in notes:
            print(f"- {note}")
    if alerts:
        print("Actionable alerts:")
        for alert in alerts:
            print(f"- {alert}")
    else:
        print("Actionable alerts: none")
    raise SystemExit(0)

if alerts:
    print("Otto no-agent health alerts:")
    for alert in alerts:
        print(f"- {alert}")
