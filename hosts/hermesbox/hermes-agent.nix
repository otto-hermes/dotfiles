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

  hermesCronSync = pkgs.writeShellScript "hermes-cron-sync" ''
    set -euo pipefail
    export HOME=/home/hermes
    exec ${pkgs.python3}/bin/python3 /home/hermes/dotfiles/hosts/hermesbox/hermes-cron-sync.py
  '';

  hermesDailyNixosRebuild = pkgs.writeShellScript "hermes-daily-nixos-rebuild" ''
    set -euo pipefail

    flake_dir=/home/hermes/dotfiles
    hostname="$(${pkgs.coreutils}/bin/cat /proc/sys/kernel/hostname)"
    target="$flake_dir#$hostname"

    export NIX_CONFIG="experimental-features = nix-command flakes"
    export PATH="${dailyNixosRebuildPath}:$PATH"

    echo "==> Updating flake inputs in $flake_dir"
    ${pkgs.sudo}/bin/sudo -u hermes HOME=/home/hermes ${pkgs.bash}/bin/bash -c 'export PATH="${dailyNixosRebuildPath}:$PATH"; exec ${pkgs.nix}/bin/nix flake update --flake "$1"' -- "$flake_dir"

    echo "==> Building NixOS configuration $target"
    if ! ${pkgs.nixos-rebuild}/bin/nixos-rebuild build --flake "$target"; then
      echo "==> Host-specific target failed; retrying build with $flake_dir"
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild build --flake "$flake_dir"
      target="$flake_dir"
    fi

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
    extraDependencyGroups = [ "messaging" ];

    # Transition-safe secret loading: keep the legacy operator-managed env file
    # as fallback, then let sops-nix's generated runtime env override it when
    # available. Note: this Hermes module concatenates these files during
    # activation, so do not use systemd's optional '-' EnvironmentFile marker.
    environmentFiles = [
      "/home/hermes/.keys/hermes.env"
      config.sops.secrets."hermes/env".path
    ];
    environment = {
      WHATSAPP_ENABLED = "false";
    };

    settings = {
      model = {
        provider = "openrouter";
        default = "deepseek/deepseek-v4-flash";
      };
      fallback_providers = [
        {
          provider = "openrouter";
          model = "google/gemini-2.5-flash-lite";
        }
      ];
      toolsets = [ "all" ];
      agent = {
        max_turns = 100;
        reasoning_effort = "medium";
      };
      skills = {
        creation_nudge_interval = 50;
        disabled = [
          "audiocraft"
          "axolotl"
          "comfyui"
          "dspy"
          "godmode"
          "huggingface-hub"
          "jupyter-live-kernel"
          "llama-cpp"
          "lm-evaluation-harness"
          "minecraft-modpack-server"
          "obliteratus"
          "openhue"
          "outlines"
          "pokemon-player"
          "segment-anything"
          "touchdesigner-mcp"
          "trl-fine-tuning"
          "unsloth"
          "vllm"
          "weights-and-biases"
          "yuanbao"
        ];
      };
      terminal = {
        backend = "local";
        cwd = "/home/hermes";
        timeout = 180;
      };
      memory = {
        nudge_interval = 50;
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
          provider = "openrouter";
          model = "google/gemini-2.5-flash-lite";
        };
        vision = {
          provider = "openrouter";
          model = "google/gemini-2.5-flash-lite";
        };
        web_extract = {
          provider = "openrouter";
          model = "google/gemini-2.5-flash-lite";
        };
        title_generation = {
          provider = "openrouter";
          model = "google/gemini-2.5-flash-lite";
        };
      };
      approvals.mode = "off";
      security.tirith_enabled = false;
      unauthorized_dm_behavior = "pair";

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
      ripgrep
      tree
      wget
    ];
  };

  systemd.services.hermes-agent = {
    serviceConfig = {
      # Allow controlled privilege escalation from agent sessions (optional/risky).
      NoNewPrivileges = lib.mkForce false;
      ReadWritePaths = lib.mkAfter [
        "/home/hermes"
        "/home/hermes/.keys"
      ];
    };

    environment = {
      HYPERFRAMES_BROWSER_PATH = "${pkgs.chromium}/bin/chromium";
      PRODUCER_HEADLESS_SHELL_PATH = "${pkgs.chromium}/bin/chromium";
      PRODUCER_FORCE_SCREENSHOT = "true";

      # Force non-interactive agent tool execution through a POSIX-compatible
      # shell. Fish remains installed for explicit human use, but automation and
      # service-launched agent sessions should not inherit fish semantics.
      SHELL = lib.mkForce "${pkgs.bashInteractive}/bin/bash";

      # Keep WhatsApp disabled for now (override env file).
      WHATSAPP_ENABLED = lib.mkForce "false";
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
      # Match hermes-agent.service: dashboard-spawned TUI/chat sessions should
      # use bash/POSIX semantics for programmatic command execution.
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
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [
        "/home/hermes"
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
    if [ -e /home/hermes/.hermes/.env ]; then
      cat >> /home/hermes/.hermes/.env <<'EOF'
WHATSAPP_ENABLED=false
EOF
      chown hermes:hermes /home/hermes/.hermes/.env
      chmod 0640 /home/hermes/.hermes/.env
    fi
  '';

  system.activationScripts."hermes-scripts" = lib.stringAfter [ "hermes-agent-setup" ] ''
    install -d -m 0755 -o hermes -g hermes /home/hermes/.hermes/scripts
    cp --no-preserve=mode,ownership /home/hermes/dotfiles/hosts/hermesbox/scripts/no-agent-health-check.py /home/hermes/.hermes/scripts/no-agent-health-check.py
    cp --no-preserve=mode,ownership /home/hermes/dotfiles/hosts/hermesbox/scripts/daily-dotfiles-nixos-rebuild.py /home/hermes/.hermes/scripts/daily-dotfiles-nixos-rebuild.py
    chown hermes:hermes /home/hermes/.hermes/scripts/no-agent-health-check.py
    chown hermes:hermes /home/hermes/.hermes/scripts/daily-dotfiles-nixos-rebuild.py
    chmod 0755 /home/hermes/.hermes/scripts/no-agent-health-check.py
    chmod 0755 /home/hermes/.hermes/scripts/daily-dotfiles-nixos-rebuild.py
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

  systemd.services.hermes-cron-sync = {
    description = "Sync Hermes cron jobs from declarative dotfiles spec";
    after = [ "hermes-agent.service" ];
    wants = [ "hermes-agent.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "hermes";
      Group = "hermes";
      ExecStart = hermesCronSync;
    };
  };

  systemd.timers.hermes-cron-sync = {
    wantedBy = [ "timers.target" ];
    partOf = [ "hermes-cron-sync.service" ];
    timerConfig = {
      OnBootSec = "3m";
      OnUnitActiveSec = "6h";
      Unit = "hermes-cron-sync.service";
      Persistent = true;
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
