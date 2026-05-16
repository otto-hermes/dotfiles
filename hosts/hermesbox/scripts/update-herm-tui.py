#!/usr/bin/env python3
"""Update the declarative herm-tui Nix package from npm metadata.

This rewrites packages/herm-tui.nix to the requested npm dist-tag/version and
keeps hashes in SRI form, so Nix can fetch the exact tarballs reproducibly.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PACKAGE_NIX = REPO_ROOT / "packages" / "herm-tui.nix"


def npm_view(spec: str) -> dict:
    out = subprocess.check_output(["npm", "view", spec, "--json"], text=True)
    return json.loads(out)


def replace_unique(text: str, pattern: str, repl: str) -> str:
    new, count = re.subn(pattern, repl, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise RuntimeError(f"expected exactly one match for {pattern!r}, got {count}")
    return new


def main() -> int:
    parser = argparse.ArgumentParser(description="Update packages/herm-tui.nix")
    parser.add_argument(
        "version",
        nargs="?",
        default="latest",
        help="npm version or dist-tag to install, default: latest; use 'next' for dev builds",
    )
    args = parser.parse_args()

    herm = npm_view(f"herm-tui@{args.version}")
    version = herm["version"]
    herm_hash = herm["dist"]["integrity"]

    optional = herm.get("optionalDependencies", {})
    opentui_version = optional.get("@opentui/core-linux-arm64")
    if not opentui_version:
        raise RuntimeError("herm-tui metadata has no @opentui/core-linux-arm64 optionalDependency")

    opentui = npm_view(f"@opentui/core-linux-arm64@{opentui_version}")
    opentui_hash = opentui["dist"]["integrity"]

    text = PACKAGE_NIX.read_text()
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
    PACKAGE_NIX.write_text(text)

    print(f"Updated herm-tui to {version}")
    print(f"@opentui/core-linux-arm64 {opentui_version}")
    print("Next: nix build .#herm-tui, then sudo nixos-rebuild switch --flake .#hermesbox")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
