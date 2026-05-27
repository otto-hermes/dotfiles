{ config, hermes-agent, lib, pkgs, ... }:

let
  dailyNixosRebuildPath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.git
    pkgs.nix
    pkgs.nixos-rebuild
    pkgs.openssh
    pkgs.sudo
    pkgs.systemd
  ];

  hermesDailyNixosRebuild = pkgs.writeShellScript "hermes-daily-nixos-rebuild" ''
    set -euo pipefail

    flake_dir=/home/hermes/dotfiles
    hostname="$(${pkgs.coreutils}/bin/cat /proc/sys/kernel/hostname)"
    target="$flake_dir#$hostname"

    export NIX_CONFIG="experimental-features = nix-command flakes"
    export PATH="${dailyNixosRebuildPath}:$PATH"

    echo "==> Updating flake inputs in $flake_dir"
    ${pkgs.sudo}/bin/sudo -u hermes HOME=/home/hermes \
      env PATH="${dailyNixosRebuildPath}" \
      ${pkgs.nix}/bin/nix flake update --flake "$flake_dir"

    echo "==> Switching NixOS configuration $target"
    ${pkgs.nixos-rebuild}/bin/nixos-rebuild switch --flake "$target"
  '';

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

  hermesAuthReset = pkgs.writeShellScript "hermes-auth-reset" ''
    set -euo pipefail
    export HOME=/home/hermes

    auth_file=/home/hermes/.hermes/auth.json
    if [ ! -r "$auth_file" ]; then
      exit 0
    fi

    now="$(${pkgs.coreutils}/bin/date +%s)"
    providers="$(${pkgs.jq}/bin/jq -r --argjson now "$now" '
      (.credential_pool // {})
      | to_entries[]
      | select(any(.value[]?;
          .last_status == "exhausted"
          and (
            (((.last_error_reset_at // 0) | tonumber? // 0) > 0
              and ((.last_error_reset_at | tonumber) <= $now))
            or (((.last_error_reset_at // null) == null)
              and (((.last_status_at // 0) | tonumber? // 0) > 0)
              and ((((.last_status_at // 0) | tonumber) + 3600) <= $now))
          )
        ))
      | .key
    ' "$auth_file")"

    if [ -z "$providers" ]; then
      exit 0
    fi

    for provider in $providers; do
      ${pkgs.sudo}/bin/sudo -u hermes HOME=/home/hermes /run/current-system/sw/bin/hermes auth reset "$provider"
    done
    ${pkgs.systemd}/bin/systemctl try-restart hermes-agent.service
  '';

  hyperframes = pkgs.writeShellScriptBin "hyperframes" ''
    set -euo pipefail
    export HOME="''${HOME:-/home/hermes}"
    export npm_config_cache="''${npm_config_cache:-/home/hermes/.npm}"
    export PATH="${lib.makeBinPath [ pkgs.nodejs_22 pkgs.ffmpeg pkgs.chromium pkgs.espeak-ng pkgs.coreutils ]}:$PATH"
    export HYPERFRAMES_BROWSER_PATH="${pkgs.chromium}/bin/chromium"
    export PRODUCER_HEADLESS_SHELL_PATH="${pkgs.chromium}/bin/chromium"
    export PRODUCER_FORCE_SCREENSHOT="''${PRODUCER_FORCE_SCREENSHOT:-true}"
    exec ${pkgs.nodejs_22}/bin/npx -y hyperframes@0.4.45 "$@"
  '';

in
{
  users.groups.hermes = { };

  users.users.hermes.extraGroups = [ "hermes" ];

  services.hermes-agent = {
    enable = true;
    createUser = false;
    user = "hermes";
    group = "hermes";

    # Keep the CLI and gateway on the same managed state directory.
    addToSystemPackages = true;
    stateDir = "/home/hermes";
    workingDirectory = "/home/hermes/workspace";
    extraDependencyGroups = [ "messaging" "fal" "firecrawl" ];

    environmentFiles = [
      # sops-decrypted env is the source of truth for secrets.
      # The legacy .keys/hermes.env has been retired — same content exists here.
      config.sops.secrets."hermes/env".path
    ];
    environment = {
      WHATSAPP_ENABLED = "false";
    };

    settings =
      let
        defaultToolsets = [
          "web"
          "browser"
          "terminal"
          "file"
          "code_execution"
          "skills"
          "clarify"
          "todo"
          "memory"
          "session_search"
          "delegation"
          "cronjob"
          "messaging"
          "vision"
          "image_gen"
          "video"
          "video_gen"
          "x_search"
          "moa"
          "tts"
          "homeassistant"
          "spotify"
          "yuanbao"
          "computer_use"
          "no_mcp"
        ];
      in {
      web = {
        backend = "firecrawl";
        extract_backend = "firecrawl";
      };
      model = {
        provider = "nous";
        default = "deepseek/deepseek-v4-flash:free";
      };
      fallback_providers = [
        {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash";
        }
      ];
      toolsets = defaultToolsets;
      agent = {
        max_turns = 90;
        reasoning_effort = "medium";
      };
      skills = {
        external_dirs = [ "/home/hermes/.hermes/skills" ];
        creation_nudge_interval = 15;
        disabled = [];
      };
      terminal = {
        backend = "local";
        cwd = "/home/hermes";
        timeout = 240;
      };
      memory = {
        nudge_interval = 10;
        memory_enabled = true;
        user_profile_enabled = true;
        memory_char_limit = 6600;
        user_char_limit = 4125;
      };
      compression = {
        enabled = true;
        threshold = 0.40;
        target_ratio = 0.20;
        protect_last_n = 8;
      };
      auxiliary = {
        compression = {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash:free";
          fallback_chain = [
            {
              provider = "nous";
              model = "deepseek/deepseek-v4-flash";
            }
          ];
        };
        vision = {
          provider = "nous";
          model = "google/gemini-3-flash-preview";
          fallback_chain = [
            {
              provider = "nous";
              model = "google/gemini-2.5-flash";
            }
          ];
        };
        web_extract = {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash:free";
          fallback_chain = [
            {
              provider = "nous";
              model = "deepseek/deepseek-v4-flash";
            }
          ];
        };
        title_generation = {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash:free";
          fallback_chain = [
            {
              provider = "nous";
              model = "deepseek/deepseek-v4-flash";
            }
          ];
        };
        triage_specifier = {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash:free";
          fallback_chain = [
            {
              provider = "nous";
              model = "deepseek/deepseek-v4-flash";
            }
          ];
        };
        kanban_decomposer = {
          provider = "nous";
          model = "deepseek/deepseek-v4-flash:free";
          fallback_chain = [
            {
              provider = "nous";
              model = "deepseek/deepseek-v4-flash";
            }
          ];
        };
      };
      approvals.mode = "off";
      security.tirith_enabled = false;
      unauthorized_dm_behavior = "pair";

      stt = {
        enabled = true;
        provider = "openai";
      };

      tts = {
        # Use edge-tts as an external CLI instead of Hermes' built-in Python
        # provider. The built-in provider imports edge_tts into Hermes' sealed
        # Python 3.12 venv; edge-tts depends on aiohttp, which collides with
        # Hermes core deps and is intentionally rejected by the Nix wrapper.
        provider = "edge-cli";
        providers.edge-cli = {
          type = "command";
          command = "edge-tts --file {input_path} --voice {voice} --write-media {output_path}";
          output_format = "mp3";
          voice = "en-US-EmmaMultilingualNeural";
          voice_compatible = true;
        };
      };

      telegram = {
      };
      whatsapp = {
        bridge_script = "/home/hermes/.hermes/platforms/whatsapp/bridge/bridge.js";
      };
      platforms.whatsapp.extra.bridge_script = "/home/hermes/.hermes/platforms/whatsapp/bridge/bridge.js";
    };

    extraPackages = with pkgs; [
      curl
      espeak-ng
      fd
      ffmpeg
      git
      himalaya
      hyperframes
      jq
      nodejs_22
      chromium
      python312Packages.edge-tts
      ripgrep
      tree
      wget
    ];
  };

  systemd.services.hermes-agent = {
    serviceConfig = {
      # Hermes agents may run `sudo` in terminal commands (nixos-rebuild,
      # systemctl, git-as-root). NoNewPrivileges blocks privilege escalation
      # even from inside the service' own process tree, so we must disable it.
      NoNewPrivileges = lib.mkForce false;
      TimeoutStopSec = "240s";
      UnsetEnvironment = [ "MESSAGING_CWD" ];
      ReadWritePaths = lib.mkAfter [
        "/home/hermes"
        "/home/hermes/.keys"
      ];
    };

    environment = {
      HYPERFRAMES_BROWSER_PATH = "${pkgs.chromium}/bin/chromium";
      PRODUCER_HEADLESS_SHELL_PATH = "${pkgs.chromium}/bin/chromium";
      PRODUCER_FORCE_SCREENSHOT = "true";
      SHELL = lib.mkForce "${pkgs.bashInteractive}/bin/bash";
      WHATSAPP_ENABLED = lib.mkForce "false";
      API_SERVER_ENABLED = lib.mkForce "true";
      API_SERVER_HOST = lib.mkForce "127.0.0.1";
      API_SERVER_PORT = lib.mkForce "8642";
      API_SERVER_KEY = lib.mkForce "";
    };
  };

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

  system.activationScripts."hermes-keys" = lib.stringAfter [ "hermes-agent-setup" ] ''
    install -d -m 0700 -o hermes -g hermes /home/hermes/.keys
    if [ -e /home/hermes/.keys/hermes.env ]; then
      chown hermes:hermes /home/hermes/.keys/hermes.env
      chmod 0600 /home/hermes/.keys/hermes.env
    fi
    if [ ! -e /home/hermes/.keys/hermes-workspace.env ]; then
      umask 077
      workspace_password="$(${pkgs.openssl}/bin/openssl rand -base64 32)"
      printf 'HERMES_WORKSPACE_PASSWORD=%s\n' "$workspace_password" > /home/hermes/.keys/hermes-workspace.env
    fi
    chown hermes:hermes /home/hermes/.keys/hermes-workspace.env
    chmod 0600 /home/hermes/.keys/hermes-workspace.env
    # .env ownership and permissions are handled by the upstream
    # hermes-agent-setup activation script. No need to touch it here.
  '';

  system.activationScripts."hermes-scripts" = lib.stringAfter [ "hermes-agent-setup" ] ''
    install -d -m 0755 -o hermes -g hermes /home/hermes/.hermes/scripts
    install -m 0755 -o hermes -g hermes \
      /home/hermes/dotfiles/hosts/hermesbox/scripts/no-agent-health-check.py \
      /home/hermes/.hermes/scripts/no-agent-health-check.py
    install -m 0755 -o hermes -g hermes \
      /home/hermes/dotfiles/hosts/hermesbox/scripts/daily-dotfiles-nixos-rebuild.py \
      /home/hermes/.hermes/scripts/daily-dotfiles-nixos-rebuild.py
  '';

  systemd.services.hermes-daily-nixos-rebuild = {
    description = "Daily NixOS flake update, build, and switch triggered by Hermes cron";
    after = [ "network-online.target" "nix-daemon.service" ];
    wants = [ "network-online.target" ];
    path = [
      pkgs.bash
      pkgs.coreutils
      pkgs.git
      pkgs.nix
      pkgs.nixos-rebuild
      pkgs.openssh
      pkgs.sudo
      pkgs.systemd
    ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      WorkingDirectory = "/home/hermes/dotfiles";
      ExecStart = hermesDailyNixosRebuild;
      TimeoutStartSec = "2h";
    };
  };

  systemd.services.hermes-auth-reset = {
    description = "Clear stale Hermes provider exhaustion state";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      ExecStart = hermesAuthReset;
    };
  };

  systemd.timers.hermes-auth-reset = {
    wantedBy = [ "timers.target" ];
    partOf = [ "hermes-auth-reset.service" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Unit = "hermes-auth-reset.service";
      Persistent = true;
    };
  };
}
