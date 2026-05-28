{ config, lib, pkgs, ... }:

let
  hermesDashboardTailscale = pkgs.writeShellScript "hermes-dashboard-tailscale" ''
    set -euo pipefail

    for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
      tail_ip="$(${pkgs.tailscale}/bin/tailscale ip -4 2>/dev/null | ${pkgs.coreutils}/bin/head -n1 || true)"
      if [ -n "$tail_ip" ]; then
        exec env PYTHONPATH=/home/hermes/dotfiles/hermes-dashboard-patch''${PYTHONPATH:+:$PYTHONPATH} /run/current-system/sw/bin/hermes dashboard --host "$tail_ip" --port 9119 --no-open --tui --insecure
      fi
      ${pkgs.coreutils}/bin/sleep 2
    done

    echo "tailscale IPv4 address was not available for Hermes dashboard binding" >&2
    exit 1
  '';

  contextUsagePython = pkgs.python3.withPackages (ps: [ ps.tiktoken ]);

  hermesContextUsageDashboard = pkgs.writeShellScript "hermes-context-usage-dashboard" ''
    set -euo pipefail

    for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
      tail_ip="$(${pkgs.tailscale}/bin/tailscale ip -4 2>/dev/null | ${pkgs.coreutils}/bin/head -n1 || true)"
      if [ -n "$tail_ip" ]; then
        exec ${contextUsagePython}/bin/python3 /home/hermes/dotfiles/hosts/hermesbox/scripts/context-usage-dashboard.py --host "$tail_ip" --port 9121
      fi
      ${pkgs.coreutils}/bin/sleep 2
    done

    echo "tailscale IPv4 address was not available for Hermes context usage dashboard binding" >&2
    exit 1
  '';

  hermesWorkspace = pkgs.buildNpmPackage rec {
    pname = "hermes-workspace";
    # When bumping: update rev + src.hash below, update the locked
    # package-lock.json in ./hermes-workspace/ to match the new source,
    # and recompute npmDepsHash (set to lib.fakeHash, build once, copy
    # the suggested hash from the error). The update-ui-components.py
    # cron script handles rev + src.hash automatically but does NOT
    # touch package-lock.json or npmDepsHash — you must regenerate
    # the lockfile and hash manually after each rev bump.
    version = "2.3.0-4f75b583";
    src = pkgs.fetchFromGitHub {
      owner = "outsourc-e";
      repo = "hermes-workspace";
      rev = "4f75b5835cc2f275e36d8adc28deb558844bceb5";
      hash = "sha256-Cg/X0JM3hvbzx0tZgzpObrEzLo+hOW8bEwuXvnTgYEQ=";
    };

    postPatch = ''
      cp ${./hermes-workspace/package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-Kx8dxSXAJe5Az0LDcUKgFmMXVtNh3el2lUBFJPM/zIc=";
    npmFlags = [ "--legacy-peer-deps" ];
    NODE_OPTIONS = "--max-old-space-size=2048";
    ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
    PUPPETEER_SKIP_DOWNLOAD = "1";
    npmBuildScript = "build";

    postInstall = ''
      cp -r dist "$out/lib/node_modules/hermes-workspace/"
    '';
  };

  hermesWorkspaceDashboard = pkgs.writeShellScript "hermes-workspace-dashboard" ''
    set -euo pipefail

    for _ in $(${pkgs.coreutils}/bin/seq 1 60); do
      tail_ip="$(${pkgs.tailscale}/bin/tailscale ip -4 2>/dev/null | ${pkgs.coreutils}/bin/head -n1 || true)"
      if [ -n "$tail_ip" ]; then
        set -a
        if [ -r /home/hermes/.hermes/.env ]; then
          . /home/hermes/.hermes/.env
        fi
        if [ -r /home/hermes/.keys/hermes-workspace.env ]; then
          . /home/hermes/.keys/hermes-workspace.env
        fi
        set +a

        export HOME=/home/hermes
        export HERMES_HOME=/home/hermes/.hermes
        export NODE_ENV=production
        export PORT=9130
        export HOST="$tail_ip"
        export COOKIE_SECURE=0
        export TRUST_PROXY=0
        export HERMES_API_URL="http://127.0.0.1:8642"
        export HERMES_DASHBOARD_URL="http://$tail_ip:9119"
        export HERMES_API_TOKEN="''${HERMES_API_TOKEN:-''${API_SERVER_KEY:-}}"
        export HERMES_PASSWORD="''${HERMES_PASSWORD:-''${HERMES_WORKSPACE_PASSWORD:-}}"

        if [ -z "''${HERMES_PASSWORD:-}" ]; then
          echo "HERMES_PASSWORD/HERMES_WORKSPACE_PASSWORD is required for Tailscale-bound Hermes Workspace" >&2
          exit 1
        fi

        exec ${pkgs.nodejs_22}/bin/node ${hermesWorkspace}/lib/node_modules/hermes-workspace/server-entry.js
      fi
      ${pkgs.coreutils}/bin/sleep 2
    done

    echo "tailscale IPv4 address was not available for Hermes Workspace binding" >&2
    exit 1
  '';

in
{
  systemd.services.hermes-dashboard = {
    description = "Hermes Agent local web dashboard";
    after = [ "network-online.target" "hermes-agent.service" "tailscaled-autoconnect.service" ];
    wants = [ "network-online.target" "tailscaled-autoconnect.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      HOME = "/home/hermes";
      HERMES_HOME = "/home/hermes/.hermes";
      HERMES_DASHBOARD_TUI = "1";
      SHELL = "${pkgs.bashInteractive}/bin/bash";
    };
    serviceConfig = {
      Type = "simple";
      User = "hermes";
      Group = "hermes";
      WorkingDirectory = "/home/hermes";
      ExecStart = hermesDashboardTailscale;
      Restart = "on-failure";
      RestartSec = "5s";
      TimeoutStopSec = "15s";
      NoNewPrivileges = lib.mkForce false;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [
        "/home/hermes"
      ];
    };
  };

  systemd.services.hermes-workspace-dashboard = {
    description = "Hermes Workspace dashboard UI";
    after = [ "network-online.target" "hermes-agent.service" "hermes-dashboard.service" "tailscaled-autoconnect.service" ];
    wants = [ "network-online.target" "hermes-agent.service" "hermes-dashboard.service" "tailscaled-autoconnect.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      HOME = "/home/hermes";
      HERMES_HOME = "/home/hermes/.hermes";
      SHELL = "${pkgs.bashInteractive}/bin/bash";
    };
    path = with pkgs; [
      bash
      coreutils
      nodejs_22
      tailscale
    ];
    serviceConfig = {
      Type = "simple";
      User = "hermes";
      Group = "hermes";
      WorkingDirectory = "/home/hermes";
      ExecStart = hermesWorkspaceDashboard;
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadOnlyPaths = [
        "/home/hermes/dotfiles"
      ];
      ReadWritePaths = [
        "/home/hermes/.hermes"
        "/home/hermes/.keys"
      ];
    };
  };

  systemd.services.hermes-context-usage-dashboard = {
    description = "Hermes prompt/context token usage dashboard";
    after = [ "network-online.target" "tailscaled-autoconnect.service" ];
    wants = [ "network-online.target" "tailscaled-autoconnect.service" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      HOME = "/home/hermes";
      HERMES_HOME = "/home/hermes/.hermes";
    };
    serviceConfig = {
      Type = "simple";
      User = "hermes";
      Group = "hermes";
      WorkingDirectory = "/home/hermes";
      ExecStart = hermesContextUsageDashboard;
      Restart = "on-failure";
      RestartSec = "5s";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadOnlyPaths = [
        "/home/hermes/.hermes"
        "/home/hermes/dotfiles"
      ];
    };
  };
}