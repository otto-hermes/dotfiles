#!/usr/bin/env python3
"""Update declarative Nix packages (herm-tui and hermes-workspace) from upstream metadata.

This script fetches latest versions and hashes for both the Herm TUI and
the Hermes Workspace dashboard, then patches the Nix configuration.

Can run as no_agent cron or agent-triggered. When no_agent, the cronsync
service provides a minimal PATH so all binary calls use full paths.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# The Nix dotfiles repo lives at a fixed path. Cron runs this script from
# ~/.hermes/scripts/ where __file__-relative resolution breaks, so hardcode.
REPO_ROOT = Path("/home/hermes/dotfiles")
AGENT_NIX = REPO_ROOT / "hosts" / "hermesbox" / "hermes-agent.nix"
HERM_TUI_NIX = REPO_ROOT / "packages" / "herm-tui.nix"

# The dotfiles root is also where we run git commands for pre-rebuild commits.
DOTFILES_GIT_DIR = REPO_ROOT

# Known tool locations — the cronsync service's PATH is too minimal for npm,
# git, and nix-prefetch-url.
_NIX_SW = "/run/current-system/sw/bin"
_NIX_PROFILE = "/nix/var/nix/profiles/default/bin"
_USER_PROFILE = "/etc/profiles/per-user/hermes/bin"

# Ensure PATH covers everything we need, preserving any existing value.
os.environ.setdefault(
    "PATH",
    f"{_USER_PROFILE}:{_NIX_SW}:{_NIX_PROFILE}",
)


def npm_view(spec: str) -> dict:
    print(f"  Checking npm: {spec}")
    out = subprocess.check_output(
        [f"{_USER_PROFILE}/npm", "view", spec, "--json"], text=True
    )
    return json.loads(out)


def get_git_rev_hash(repo_url: str, branch: str = "main") -> tuple[str, str]:
    print(f"  Checking git: {repo_url} ({branch})")
    rev = subprocess.check_output(
        [f"{_NIX_SW}/git", "ls-remote", repo_url, branch], text=True
    ).split()[0]

    # Try nix-prefetch-github from the nix profile first
    prefetch_gh = f"{_NIX_PROFILE}/nix-prefetch-github"
    try:
        out = json.loads(
            subprocess.check_output(
                [prefetch_gh, "outsourc-e", "hermes-workspace", "--rev", rev],
                text=True,
            )
        )
        return rev, out["hash"]
    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
        print("  nix-prefetch-github failed, falling back to nix-prefetch-url...")
        prefetch_url = f"{_NIX_PROFILE}/nix-prefetch-url"
        archive_url = f"{repo_url.rstrip('.git')}/archive/{rev}.tar.gz"
        sha256 = subprocess.check_output(
            [prefetch_url, "--unpack", "--type", "sha256", archive_url], text=True
        ).strip()
        return rev, sha256


def replace_unique(text: str, pattern: str, repl: str) -> str:
    new, count = re.subn(pattern, repl, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError(f"expected exactly one match for {pattern!r}, got {count}")
    return new


def update_herm_tui(version_spec: str) -> str:
    herm = npm_view(f"herm-tui@{version_spec}")
    version = herm["version"]
    herm_hash = herm["dist"]["integrity"]

    optional = herm.get("optionalDependencies", {})
    opentui_version = optional.get("@opentui/core-linux-arm64")
    if not opentui_version:
        return f"Error: herm-tui@{version} has no @opentui/core-linux-arm64"

    opentui = npm_view(f"@opentui/core-linux-arm64@{opentui_version}")
    opentui_hash = opentui["dist"]["integrity"]

    text = HERM_TUI_NIX.read_text()
    text = replace_unique(text, r'version = "[^"]+";', f'version = "{version}";')
    text = replace_unique(text, r'opentuiCoreVersion = "[^"]+";', f'opentuiCoreVersion = "{opentui_version}";')
    text = replace_unique(
        text,
        r'url = "https://registry\.npmjs\.org/herm-tui/-/herm-tui-\$\{version\}\.tgz";\n\s*hash = "[^"]+";',
        f'url = "https://registry.npmjs.org/herm-tui/-/herm-tui-${{version}}.tgz";\n    hash = "{herm_hash}";',
    )
    text = replace_unique(
        text,
        r'url = "https://registry\.npmjs\.org/@opentui/core-linux-arm64/-/core-linux-arm64-\$\{opentuiCoreVersion\}\.tgz";\n\s*hash = "[^"]+";',
        f'url = "https://registry.npmjs.org/@opentui/core-linux-arm64/-/core-linux-arm64-${{opentuiCoreVersion}}.tgz";\n    hash = "{opentui_hash}";',
    )
    HERM_TUI_NIX.write_text(text)
    return f"Updated herm-tui to {version} (@opentui {opentui_version})"


def update_hermes_workspace() -> str:
    repo_url = "https://github.com/outsourc-e/hermes-workspace.git"
    rev, sri_hash = get_git_rev_hash(repo_url)

    text = AGENT_NIX.read_text()

    ver_match = re.search(r'version = "([^"-]+)-[^"]+";', text)
    ver_prefix = ver_match.group(1) if ver_match else "2.4.0"
    new_version = f"{ver_prefix}-{rev[:8]}"

    text = replace_unique(text, r'version = "[^"]+";\n\s+src = pkgs\.fetchFromGitHub',
                          f'version = "{new_version}";\n    src = pkgs.fetchFromGitHub')
    text = replace_unique(text, r'rev = "[^"]+";', f'rev = "{rev}";')
    text = replace_unique(text, r'hash = "[^"]+";', f'hash = "{sri_hash}";')

    AGENT_NIX.write_text(text)
    return f"Updated hermes-workspace to {new_version} (rev {rev[:8]})"


def main() -> int:
    parser = argparse.ArgumentParser(description="Update Herm TUI and Workspace Dashboard pins.")
    parser.add_argument("--tui-version", default="latest", help="npm version/tag for herm-tui")
    parser.add_argument("--skip-tui", action="store_true", help="Skip TUI update")
    parser.add_argument("--skip-workspace", action="store_true", help="Skip Workspace update")
    args = parser.parse_args()

    results = []

    if not args.skip_tui:
        try:
            results.append(update_herm_tui(args.tui_version))
        except Exception as e:
            results.append(f"TUI Update Failed: {e}")

    if not args.skip_workspace:
        try:
            results.append(update_hermes_workspace())
        except Exception as e:
            results.append(f"Workspace Update Failed: {e}")

    print("--- Update Summary ---")
    for res in results:
        print(f"  - {res}")

    # The next step is always the rebuild — the cron schedule handles ordering.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
