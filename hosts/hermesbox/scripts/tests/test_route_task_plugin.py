import importlib.util
import stat
import sys
import tempfile
import textwrap
import unittest
from pathlib import Path


PLUGIN = Path(__file__).resolve().parents[2] / "plugins" / "routing" / "__init__.py"
spec = importlib.util.spec_from_file_location("routing_plugin", PLUGIN)
assert spec is not None and spec.loader is not None
routing = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = routing
spec.loader.exec_module(routing)


class RouteTaskPluginTests(unittest.TestCase):
    def test_profiles_from_router_uses_plain_list_command(self):
        with tempfile.TemporaryDirectory() as td:
            fake = Path(td) / "hermes-profile-router"
            fake.write_text(textwrap.dedent('''\
                #!/usr/bin/env python3
                import json
                import sys

                if sys.argv[1:] != ["list"]:
                    raise SystemExit(f"unexpected argv: {sys.argv[1:]!r}")
                print(json.dumps([{"name": "setup-worker"}, {"name": "coding"}]))
            '''))
            fake.chmod(fake.stat().st_mode | stat.S_IXUSR)
            old_router_bin = routing._router_bin
            routing._router_bin = lambda: str(fake)
            try:
                self.assertEqual(routing._profiles_from_router(), ["setup-worker", "coding"])
            finally:
                routing._router_bin = old_router_bin

    def test_low_confidence_launch_refuses_without_explicit_profile(self):
        old_run_router = routing._run_router
        old_launch = routing._launch
        launched = []

        def fake_run_router(action, task):
            self.assertEqual(action, "choose")
            return {"profile": "fallback-full", "confidence": 0.2}, None

        def fake_launch(*args, **kwargs):
            launched.append((args, kwargs))
            return {"ok": True}

        routing._run_router = fake_run_router
        routing._launch = fake_launch
        try:
            result = routing.json.loads(routing.route_task({"action": "launch", "task": "do the thing"}))
        finally:
            routing._run_router = old_run_router
            routing._launch = old_launch

        self.assertEqual(result["status"], "low_confidence")
        self.assertEqual(launched, [])

    def test_confidence_floor_alias_is_supported(self):
        old_run_router = routing._run_router
        old_launch = routing._launch

        def fake_run_router(action, task):
            return {"profile": "setup-worker", "confidence": 0.4}, None

        def fake_launch(task, profile, mode, timeout_seconds):
            return {"ok": True, "status": "completed", "profile": profile}

        routing._run_router = fake_run_router
        routing._launch = fake_launch
        try:
            result = routing.json.loads(routing.route_task({
                "action": "launch",
                "task": "inspect hermes config",
                "confidence_floor": 0.35,
            }))
        finally:
            routing._run_router = old_run_router
            routing._launch = old_launch

        self.assertEqual(result["status"], "completed")
        self.assertEqual(result["profile"], "setup-worker")


if __name__ == "__main__":
    unittest.main()
