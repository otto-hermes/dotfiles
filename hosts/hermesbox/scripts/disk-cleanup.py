#!/usr/bin/env python3
"""No-agent disk cleanup: Nix GC, cache nukes, temp files.

Runs safely (no destructive deletes of active data). Exits 0 on success,
prints diagnostics on failure. Quiet when healthy (nothing to clean).
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

HOME = Path(os.environ["HOME"])
HERMES_HOME = HOME / ".hermes"
SUDO = "/run/wrappers/bin/sudo" if os.path.exists("/run/wrappers/bin/sudo") else "sudo"
SYSTEM_PROFILE = "/nix/var/nix/profiles/system"
KEEP_LAST = 4  # keep current + 3 previous


def run(cmd: list[str], timeout: int = 600) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=timeout
    )


def clean_nix_generations() -> int:
    """Delete all system generations except the last KEEP_LAST."""
    gen_list = run(
        [SUDO, "nix-env", "-p", SYSTEM_PROFILE, "--list-generations"]
    )
    if gen_list.returncode != 0:
        print(f"nix-env list-generations failed: {gen_list.stderr.strip()}")
        return 0  # non-fatal

    generations = []
    for line in gen_list.stdout.strip().split("\n"):
        parts = line.split()
        if parts and parts[0].isdigit():
            generations.append(int(parts[0]))

    if len(generations) <= KEEP_LAST:
        return 0

    to_delete = sorted(generations)[:-KEEP_LAST]
    for gen in to_delete:
        res = run([SUDO, "nix-env", "-p", SYSTEM_PROFILE, "--delete-generations", str(gen)])
        if res.returncode != 0:
            print(f"delete gen {gen} failed: {res.stderr.strip()}")

    if to_delete:
        print(f"Deleted {len(to_delete)} old generations ({to_delete[0]}-{to_delete[-1]})")
    return len(to_delete)


def clean_nix_gc() -> str | None:
    """Run nix garbage collector. Returns freed space or None on failure."""
    # remount rw if needed
    run([SUDO, "mount", "-o", "remount,rw", "/"], timeout=10)

    res = run([SUDO, "nix-collect-garbage", "-d"], timeout=1800)
    if res.returncode != 0:
        print(f"nix-collect-garbage failed: {res.stderr.strip()}")
        return None

    # Parse freed space from output
    for line in res.stdout.split("\n"):
        if "freed" in line:
            return line.strip()
    return "ok (unknown freed)"


def clean_dir(path: Path, name: str) -> int:
    """Remove a directory. Returns size in MB, or 0."""
    if not path.exists():
        return 0
    try:
        total = sum(f.stat().st_size for f in path.rglob("*") if f.is_file()) // (1024 * 1024)
        shutil.rmtree(path)
        print(f"Cleaned {name} ({total} MB)")
        return total
    except Exception as e:
        print(f"Could not clean {name}: {e}")
        return 0


def clean_cache_dir(pattern: str, name: str) -> int:
    """Clean a specific cache subdir. Returns size in MB."""
    for p in HOME.rglob(pattern):
        if p.is_dir():
            return clean_dir(p, name)
    return 0


def main() -> int:
    total_mb = 0

    # 1. Nix cleanup
    del_gens = clean_nix_generations()
    gc_result = clean_nix_gc()

    # 2. Package manager caches
    total_mb += clean_dir(HOME / ".npm" / "_cacache", "npm cache")
    total_mb += clean_dir(HOME / ".local" / "share" / "pnpm", "pnpm store")
    total_mb += clean_dir(HOME / ".cache" / "pip", "pip cache")
    total_mb += clean_dir(HOME / ".cache" / "chroma", "chroma cache")
    total_mb += clean_dir(HOME / ".cache" / "electron", "electron cache")
    total_mb += clean_dir(HOME / ".cache" / "node", "node cache")

    # 3. Hermes runtime data
    total_mb += clean_dir(HERMES_HOME / "stale-archives", "hermes stale-archives")
    total_mb += clean_dir(HERMES_HOME / "sessions", "hermes sessions")

    # 4. Stale backups
    total_mb += clean_dir(HOME / ".hermes_real", ".hermes_real backup")

    # 5. Python venvs
    for venv in HOME.glob(".venv*"):
        total_mb += clean_dir(venv, f"{venv.name}")

    # 6. Temp files
    for tmpdir in ["/tmp", "/var/tmp"]:
        p = Path(tmpdir)
        if p.exists():
            for item in p.iterdir():
                try:
                    if item.is_file() or item.is_symlink():
                        item.unlink()
                    elif item.is_dir():
                        shutil.rmtree(item)
                except Exception:
                    pass

    if total_mb > 0 and gc_result:
        print(f"Freed {total_mb} MB from caches + {gc_result} from Nix")
    elif del_gens > 0 or gc_result:
        print(f"Nix cleanup: {gc_result}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
