import re
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[4]
HERMES_AGENT_NIX = REPO / "hosts" / "hermesbox" / "hermes-agent.nix"


def default_soul_source() -> str:
    text = HERMES_AGENT_NIX.read_text()
    match = re.search(
        r'defaultSoul = pkgs\.writeText "hermes-default-SOUL\.md" \'\'\n(?P<body>.*?)\n  \'\';',
        text,
        re.S,
    )
    if match is None:
        raise AssertionError("defaultSoul writeText block not found")
    return match.group("body")


class DefaultSoulPolicyTests(unittest.TestCase):
    def test_default_soul_is_installed_declaratively(self):
        text = HERMES_AGENT_NIX.read_text()

        self.assertIn('defaultSoul = pkgs.writeText "hermes-default-SOUL.md"', text)
        self.assertIn('/home/hermes/.hermes/SOUL.md', text)
        self.assertIn('${defaultSoul}', text)
        self.assertIn('system.activationScripts."hermes-default-soul"', text)

    def test_default_soul_routes_non_trivial_specialist_work_by_policy(self):
        soul = default_soul_source()

        self.assertIn("Default is a lightweight chat/workbench and router", soul)
        self.assertIn("Route or delegate non-trivial work by default", soul)
        self.assertIn("when routing would be wasteful", soul)

        required_domains = [
            "repo edits",
            "NixOS mutations",
            "Hermes/profile/router/toolset/model/provider/service/package changes",
            "media or creative production",
            "knowledge curation",
            "wiki/session/memory work",
            "current-facts research",
            "specialist profile",
        ]
        for domain in required_domains:
            with self.subTest(domain=domain):
                self.assertIn(domain, soul)

    def test_default_soul_references_router_commands(self):
        soul = default_soul_source()

        for command in [
            "hermes-profile-router choose",
            "hermes-profile-router plan",
            "hermes-profile-router launch",
            "hermes-profile-router execute-plan",
        ]:
            with self.subTest(command=command):
                self.assertIn(command, soul)


if __name__ == "__main__":
    unittest.main()
