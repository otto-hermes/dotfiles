{ hermes-agent, lib, pkgs, ... }:

let
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

    echo "==> Updating flake inputs in $flake_dir"
    ${pkgs.sudo}/bin/sudo -u hermes HOME=/home/hermes ${pkgs.nix}/bin/nix flake update "$flake_dir"

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

  hermesAuthReset = pkgs.writeShellScript "hermes-auth-reset" ''
    set -euo pipefail
    export HOME=/home/hermes

    auth_file=/var/lib/hermes/.hermes/auth.json
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

    # Operator-managed secrets live outside Git and the Nix store.
    environmentFiles = [ "/home/hermes/.keys/hermes.env" ];

    settings = {
      model = {
        provider = "openai-codex";
        default = "gpt-5.5";
      };
      fallback_providers = [
        {
          provider = "openrouter";
          model = "google/gemini-2.5-flash-lite";
        }
      ];
      toolsets = [ "all" ];
      terminal = {
        backend = "local";
        cwd = "/home/hermes";
        timeout = 180;
      };
      memory = {
        memory_enabled = true;
        user_profile_enabled = true;
      };
      approvals.mode = "off";
      security.tirith_enabled = false;
      unauthorized_dm_behavior = "pair";
      whatsapp = {
        unauthorized_dm_behavior = "ignore";
        dm_policy = "allowlist";
        allow_from = "905333526660";
      };
      platforms.whatsapp.extra.bridge_script = "/var/lib/hermes/.hermes/platforms/whatsapp/bridge/bridge.js";
      telegram = {
      };
    };

    extraPackages = with pkgs; [
      curl
      fd
      git
      himalaya
      jq
      nodejs_22
      ripgrep
      tree
      wget
    ];
  };

  systemd.services.hermes-agent = {
    serviceConfig = {
      # Allow controlled privilege escalation from agent sessions (optional/risky).
      NoNewPrivileges = lib.mkForce false;
      WorkingDirectory = lib.mkForce "/home/hermes";
      ReadWritePaths = lib.mkAfter [
        "/home/hermes"
        "/home/hermes/.keys"
      ];
    };

    environment = {
      # Force non-interactive agent tool execution through a POSIX-compatible
      # shell. The hermes user's login shell is fish, and some Hermes/tool
      # wrappers emit POSIX snippets such as `__hermes_ec=$?`; exposing fish as
      # $SHELL causes those wrappers to fail before commands run. Keep fish as
      # the account login shell, but make service-launched agent sessions use
      # bash for programmatic terminal execution.
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
      HERMES_HOME = "/var/lib/hermes/.hermes";
      HERMES_DASHBOARD_TUI = "1";
      # Match hermes-agent.service: dashboard-spawned TUI/chat sessions should
      # not inherit fish as $SHELL for programmatic command execution.
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
        "/var/lib/hermes/.hermes"
        "/home/hermes"
      ];
    };
  };

  system.activationScripts."hermes-keys" = lib.stringAfter [ "hermes-agent-setup" ] ''
    install -d -m 0700 -o hermes -g hermes /home/hermes/.keys
    if [ -e /home/hermes/.keys/hermes.env ]; then
      chown hermes:hermes /home/hermes/.keys/hermes.env
      chmod 0600 /home/hermes/.keys/hermes.env
      ln -sfn /home/hermes/.keys/hermes.env /var/lib/hermes/.hermes/.env
      chown -h hermes:hermes /var/lib/hermes/.hermes/.env
    fi
  '';

  system.activationScripts."hermes-cli-home-link" = lib.stringAfter [ "hermes-agent-setup" ] ''
    if [ -d /home/hermes/.hermes ] && [ ! -L /home/hermes/.hermes ]; then
      mv /home/hermes/.hermes "/home/hermes/.hermes.unmanaged-backup.$(date +%s)"
    fi
    ln -sfn /var/lib/hermes/.hermes /home/hermes/.hermes
    chown -h hermes:hermes /home/hermes/.hermes
  '';

  system.activationScripts."hermes-scripts" = lib.stringAfter [ "hermes-cli-home-link" ] ''
    install -d -m 0755 -o hermes -g hermes /var/lib/hermes/.hermes/scripts
    cp --no-preserve=mode,ownership /home/hermes/dotfiles/hosts/hermesbox/scripts/no-agent-health-check.py /var/lib/hermes/.hermes/scripts/no-agent-health-check.py
    chown hermes:hermes /var/lib/hermes/.hermes/scripts/no-agent-health-check.py
    chmod 0755 /var/lib/hermes/.hermes/scripts/no-agent-health-check.py
  '';

  system.activationScripts."hermes-whatsapp-bridge" = lib.stringAfter [ "hermes-agent-setup" ] ''
    bridge_dir=/var/lib/hermes/.hermes/platforms/whatsapp/bridge
    mkdir -p "$bridge_dir"
    cp -r --no-preserve=mode,ownership ${hermes-agent.outPath}/scripts/whatsapp-bridge/. "$bridge_dir/"
    chown -R hermes:hermes /var/lib/hermes/.hermes/platforms/whatsapp
    chmod -R u+rwX,go-rwx /var/lib/hermes/.hermes/platforms/whatsapp
  '';

  systemd.services.hermes-daily-nixos-rebuild = {
    description = "Daily NixOS flake update, build, and switch triggered by Hermes cron";
    after = [ "network-online.target" "nix-daemon.service" ];
    wants = [ "network-online.target" ];
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
