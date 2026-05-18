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

        self.assertIn("Default is a narrow Codex chat/router profile", soul)
        self.assertIn("Route or delegate non-trivial work by default", soul)
        self.assertIn("route almost anything operational", soul)

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
            "route_task",
            "hermes-profile-router choose",
            "hermes-profile-router plan",
            "hermes-profile-router launch",
            "hermes-profile-router execute-plan",
        ]:
            with self.subTest(command=command):
                self.assertIn(command, soul)

        self.assertIn("Do not invent tools named `profile_router`, `mentor`, or similar", soul)
        self.assertIn("do not silently launch the broad fallback profile", soul)

    def test_default_router_uses_codex_primary_model(self):
        text = HERMES_AGENT_NIX.read_text()

        self.assertIn('provider = "openai-codex";', text)
        self.assertIn('default = "gpt-5.5";', text)
        self.assertIn('provider = "openrouter";', text)
        self.assertIn('model = "google/gemini-2.5-flash-lite";', text)

    def test_default_tool_surface_is_platform_allowlisted(self):
        text = HERMES_AGENT_NIX.read_text()

        self.assertIn("defaultRouterToolsets = [", text)
        self.assertIn("platformRouterToolsets = defaultRouterToolsets ++ [ \"no_mcp\" ];", text)
        self.assertIn("platform_toolsets = lib.genAttrs routerPlatforms (_: platformRouterToolsets);", text)
        self.assertIn("known_plugin_toolsets = lib.genAttrs routerPlatforms (_: [ \"routing\" ]);", text)

        match = re.search(
            r"defaultRouterToolsets = \[\n(?P<body>.*?)\n        \];",
            text,
            re.S,
        )
        self.assertIsNotNone(match)
        router_toolsets = match.group("body")

        for broad_toolset in [
            "terminal",
            "file",
            "browser",
            "web",
            "code_execution",
            "delegation",
            "messaging",
        ]:
            with self.subTest(toolset=broad_toolset):
                self.assertNotIn(f'"{broad_toolset}"', router_toolsets)

    def test_gateway_service_clears_deprecated_runtime_warnings(self):
        text = HERMES_AGENT_NIX.read_text()

        self.assertIn('TimeoutStopSec = "240s";', text)
        self.assertIn('UnsetEnvironment = [ "MESSAGING_CWD" ];', text)


if __name__ == "__main__":
    unittest.main()
