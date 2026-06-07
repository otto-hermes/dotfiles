{ config, lib, pkgs, ... }:

let
  hermesAuthReset = pkgs.writeShellScript "hermes-auth-reset" ''
    set -euo pipefail
    export HOME=/home/hermes

    auth_file=/home/hermes/.hermes/auth.json
    if [ ! -r "$auth_file" ]; then
      exit 0
    fi

    now="$(${pkgs.coreutils}/bin/date +%s)"
    # This workaround exists for OpenAI Codex OAuth quota windows: once the
    # quota refreshes, Hermes may still carry a stale local "exhausted" marker
    # until the gateway reloads auth state. Do not apply it to OpenRouter free
    # routes; their 429s are real upstream/provider rate limits, and resetting
    # local state just causes repeated gateway restarts without restoring quota.
    providers="$(${pkgs.jq}/bin/jq -r --argjson now "$now" '
      (.credential_pool // {})
      | to_entries[]
      | select(.key == "openai-codex")
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

    echo "==> Restarting Hermes services after switch"
    ${pkgs.systemd}/bin/systemctl try-restart \
      hermes-agent.service \
      hermes-dashboard.service \
      hermes-workspace-dashboard.service \
      hermes-context-usage-dashboard.service
  '';


  hermesDailyNixosRebuildNotify = pkgs.writeShellScript "hermes-daily-nixos-rebuild-notify" ''
    set -euo pipefail

    unit="hermes-daily-nixos-rebuild.service"

    set -a
    if [ -r /home/hermes/.keys/hermes.env ]; then
      . /home/hermes/.keys/hermes.env
    elif [ -r /home/hermes/.hermes/.env ]; then
      . /home/hermes/.hermes/.env
    fi
    set +a

    if [ -z "''${TELEGRAM_BOT_TOKEN:-}" ] || [ -z "''${TELEGRAM_HOME_CHANNEL:-}" ]; then
      echo "Telegram maintenance alert skipped: TELEGRAM_BOT_TOKEN or TELEGRAM_HOME_CHANNEL is unset" >&2
      exit 0
    fi

    journal="$(${pkgs.systemd}/bin/journalctl -u "$unit" -n 80 --no-pager -o short-iso 2>&1 || true)"
    message="$(${pkgs.coreutils}/bin/printf 'Hermesbox maintenance failed: %s\n\n%s' "$unit" "$journal")"
    message="''${message:0:3500}"
    payload="$(${pkgs.jq}/bin/jq -n \
      --arg chat_id "$TELEGRAM_HOME_CHANNEL" \
      --arg text "$message" \
      '{chat_id: $chat_id, text: $text, disable_web_page_preview: true}')"

    ${pkgs.curl}/bin/curl --fail --silent --show-error --max-time 20 \
      -H 'Content-Type: application/json' \
      -d "$payload" \
      "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" >/dev/null
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
  environment.systemPackages = [ hyperframes ];

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
    rm -f /home/hermes/.hermes/scripts/daily-dotfiles-nixos-rebuild.py
    install -m 0755 -o hermes -g hermes \
      /home/hermes/dotfiles/hosts/hermesbox/scripts/update-ui-components.py \
      /home/hermes/.hermes/scripts/update-ui-components.py
    install -m 0755 -o hermes -g hermes \
      /home/hermes/dotfiles/hosts/hermesbox/scripts/update-herm-tui.py \
      /home/hermes/.hermes/scripts/update-herm-tui.py
  '';

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

  systemd.timers.hermes-daily-nixos-rebuild = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true;
      RandomizedDelaySec = "10m";
      Unit = "hermes-daily-nixos-rebuild.service";
    };
  };


  systemd.services.hermes-daily-nixos-rebuild-notify = {
    description = "Send Telegram alert for failed daily NixOS rebuild";
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      ExecStart = hermesDailyNixosRebuildNotify;
    };
  };

  systemd.services.hermes-daily-nixos-rebuild = {
    description = "Daily NixOS flake update, build, and switch";
    after = [ "network-online.target" "nix-daemon.service" ];
    wants = [ "network-online.target" ];
    unitConfig.OnFailure = "hermes-daily-nixos-rebuild-notify.service";
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
}
