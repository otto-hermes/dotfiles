import re
import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[4]
PROFILES_NIX = REPO / "hosts" / "hermesbox" / "hermes-profiles.nix"


def source() -> str:
    return PROFILES_NIX.read_text()


def list_body(name: str) -> str:
    match = re.search(rf"  {name} = \[\n(?P<body>.*?)\n  \];", source(), re.S)
    if match is None:
        raise AssertionError(f"{name} list not found")
    return match.group("body")


def items(name: str) -> set[str]:
    return set(re.findall(r'"([^"\n]+)"', list_body(name)))


class ProfileToolSurfaceTests(unittest.TestCase):
    def test_profile_routing_plugin_is_installed_per_profile(self):
        text = source()

        self.assertIn('pname = "hermes-routing-plugin";', text)
        self.assertIn('/plugins/nix-managed-hermes-routing-plugin', text)
        self.assertIn('ln -sfn ${hermesRoutingPlugin}', text)

    def test_profiles_sync_root_and_cli_platform_toolsets(self):
        text = source()

        self.assertIn("profileToolSettings = toolsets:", text)
        self.assertIn('exposedToolsets = lib.unique (toolsets ++ [ "routing" ]);', text)
        self.assertIn('toolsets = exposedToolsets;', text)
        self.assertIn('platform_toolsets.cli = exposedToolsets ++ [ "no_mcp" ];', text)
        self.assertIn('known_plugin_toolsets.cli = [ "routing" ];', text)
        self.assertIn('plugins.enabled = [ "routing" ];', text)

    def test_high_use_workers_do_not_carry_rare_broad_tools(self):
        broad = {
            "browser",
            "vision",
            "image_gen",
            "video",
            "tts",
            "delegation",
            "messaging",
            "computer_use",
            "cronjob",
            "code_execution",
        }
        for name in ["codingToolsets", "setupToolsets", "plannerToolsets"]:
            with self.subTest(profile=name):
                self.assertFalse(items(name) & broad)

    def test_common_workers_keep_core_capability(self):
        self.assertGreaterEqual(items("codingToolsets"), {"terminal", "file", "web", "skills", "memory", "session_search", "todo", "clarify"})
        self.assertGreaterEqual(items("setupToolsets"), {"terminal", "file", "web", "skills", "memory", "session_search", "todo", "clarify"})
        self.assertEqual(items("simpleWorkerToolsets"), {"terminal", "file"})

    def test_skill_nudges_are_disabled_for_profiles(self):
        self.assertNotIn("creation_nudge_interval = 50;", source())

    def test_high_use_codex_profiles_use_tighter_context_policy(self):
        text = source()

        self.assertIn("highUseCodexMemory", text)
        self.assertIn("highUseCodexCompression", text)
        self.assertIn("memory = highUseCodexMemory;", text)
        self.assertIn("compression = highUseCodexCompression;", text)


if __name__ == "__main__":
    unittest.main()
