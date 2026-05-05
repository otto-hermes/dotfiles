"""Local dashboard hotfix loaded via PYTHONPATH by hermes-dashboard.service.

Remove this once upstream Hermes allows dashboard chat/event WebSockets for an
explicit non-loopback ``hermes dashboard --insecure --host <tailnet-ip>`` bind.
"""
from __future__ import annotations

import importlib.abc
import importlib.machinery
import sys


class _PatchedWebServerLoader(importlib.abc.Loader):
    def __init__(self, wrapped: importlib.abc.Loader):
        self._wrapped = wrapped

    def create_module(self, spec):  # pragma: no cover - delegated protocol hook
        create = getattr(self._wrapped, "create_module", None)
        if create is None:
            return None
        return create(spec)

    def exec_module(self, module):
        self._wrapped.exec_module(module)

        original_start_server = module.start_server

        def _is_public_bind() -> bool:
            """True when WebSocket clients may arrive from non-loopback IPs."""
            return (
                bool(getattr(module.app.state, "allow_public", False))
                or getattr(module.app.state, "bound_host", "") in ("0.0.0.0", "::")
            )

        def start_server(*args, **kwargs):
            allow_public = kwargs.get("allow_public", False)
            # start_server(host, port, open_browser, allow_public, *, embedded_chat)
            if len(args) >= 4:
                allow_public = args[3]
            module.app.state.allow_public = bool(allow_public)
            return original_start_server(*args, **kwargs)

        module._is_public_bind = _is_public_bind
        module.start_server = start_server


class _HermesDashboardPatchFinder(importlib.abc.MetaPathFinder):
    def find_spec(self, fullname: str, path=None, target=None):
        if fullname != "hermes_cli.web_server":
            return None
        # Ask the normal path finder for the packaged module while avoiding a
        # recursive call back into this finder.
        spec = importlib.machinery.PathFinder.find_spec(fullname, path)
        if spec is None or spec.loader is None:
            return None
        spec.loader = _PatchedWebServerLoader(spec.loader)
        return spec


sys.meta_path.insert(0, _HermesDashboardPatchFinder())
