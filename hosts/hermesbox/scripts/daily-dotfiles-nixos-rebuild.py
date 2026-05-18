#!/usr/bin/env python3
"""No-agent trigger for the declarative daily NixOS rebuild unit.

Healthy/successful runs print nothing so Hermes cron stays silent. Failures print
concise diagnostics and exit non-zero so the scheduler marks the run failed.
"""
import subprocess
import sys

UNIT = "hermes-daily-nixos-rebuild.service"
SUDO = "/run/current-system/sw/bin/sudo"
SYSTEMCTL = "/run/current-system/sw/bin/systemctl"
JOURNALCTL = "/run/current-system/sw/bin/journalctl"


def run(cmd: list[str], timeout: int | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        timeout=timeout,
    )


def main() -> int:
    start = run([SUDO, SYSTEMCTL, "start", UNIT], timeout=2 * 60 * 60 + 60)
    if start.returncode == 0:
        return 0

    status = run([SUDO, SYSTEMCTL, "status", "--no-pager", "--full", UNIT], timeout=30)
    journal = run([SUDO, JOURNALCTL, "-u", UNIT, "-n", "120", "--no-pager", "-o", "short-iso"], timeout=30)

    print(f"Daily NixOS flake update/rebuild failed: {UNIT}")
    print(f"systemctl start exit code: {start.returncode}")
    if start.stdout.strip():
        print("\nstart stdout:\n" + start.stdout.strip())
    if start.stderr.strip():
        print("\nstart stderr:\n" + start.stderr.strip())
    if status.stdout.strip() or status.stderr.strip():
        print("\nstatus:\n" + (status.stdout or status.stderr).strip())
    if journal.stdout.strip() or journal.stderr.strip():
        print("\njournal tail:\n" + (journal.stdout or journal.stderr).strip())
    return start.returncode or 1


if __name__ == "__main__":
    raise SystemExit(main())
