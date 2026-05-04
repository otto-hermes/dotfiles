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

    # Keep WhatsApp disabled for now (override env file).
    environment.WHATSAPP_ENABLED = lib.mkForce "false";
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
}
