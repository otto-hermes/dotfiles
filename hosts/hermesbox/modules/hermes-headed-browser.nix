{ config, lib, pkgs, ... }:

let
  cfg = config.services.hermes-headed-browser;
  websockifyEnv = pkgs.python3.withPackages (ps: [ ps.websockify ]);
  startScript = pkgs.writeShellScript "hermes-headed-browser-start" ''
    set -euo pipefail

    export HOME="${cfg.homeDir}"
    export DISPLAY="${cfg.display}"
    export XDG_RUNTIME_DIR="/run/user/$(id -u)"

    profile_dir="${cfg.profileDir}"
    runtime_dir="${cfg.runtimeDir}"
    mkdir -p "$profile_dir" "$runtime_dir" "$HOME/.cache/chromium" "$HOME/.config/chromium"

    cleanup() {
      trap - EXIT INT TERM
      jobs -pr | xargs -r kill 2>/dev/null || true
      wait 2>/dev/null || true
    }
    trap cleanup EXIT INT TERM

    # Avoid stale locks after an unclean VM/service shutdown. This display is private
    # to this unit, so removing its own lock/socket before startup is safe.
    rm -f /tmp/.X${toString cfg.displayNumber}-lock /tmp/.X11-unix/X${toString cfg.displayNumber}

    ${pkgs.xorg.xvfb}/bin/Xvfb ${cfg.display} \
      -screen 0 ${cfg.screen} \
      -nolisten tcp \
      -ac \
      -noreset &

    # Wait for Xvfb to accept clients before launching the window manager/browser.
    for _ in $(seq 1 50); do
      if ${pkgs.xorg.xdpyinfo}/bin/xdpyinfo -display ${cfg.display} >/dev/null 2>&1; then
        break
      fi
      sleep 0.1
    done

    ${pkgs.openbox}/bin/openbox &

    ${pkgs.chromium}/bin/chromium \
      --user-data-dir="$profile_dir" \
      --no-first-run \
      --no-default-browser-check \
      --disable-dev-shm-usage \
      --disable-gpu \
      --disable-notifications \
      --deny-permission-prompts \
      --window-size=${cfg.windowSize} \
      --remote-debugging-address=127.0.0.1 \
      --remote-debugging-port=${toString cfg.cdpPort} \
      "${cfg.startUrl}" &

    ${pkgs.x11vnc}/bin/x11vnc \
      -display ${cfg.display} \
      -localhost \
      -forever \
      -shared \
      -nopw \
      -rfbport ${toString cfg.vncPort} &

    ${websockifyEnv}/bin/websockify \
      --web ${pkgs.novnc}/share/webapps/novnc \
      127.0.0.1:${toString cfg.noVncPort} \
      127.0.0.1:${toString cfg.vncPort} &

    wait -n
  '';
in
{
  options.services.hermes-headed-browser = {
    enable = lib.mkEnableOption "headed Chromium under Xvfb/noVNC for authenticated shopping automation";

    user = lib.mkOption {
      type = lib.types.str;
      default = "hermes";
      description = "User that owns the browser profile and runs the headed browser stack.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "hermes";
      description = "Group for the headed browser stack.";
    };

    homeDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/hermes";
      description = "Home directory for the browser process.";
    };

    profileDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/hermes/.hermes/shopping/browser-profiles/hepsiburada";
      description = "Persistent Chromium user-data directory reused by manual noVNC login and Hermes automation.";
    };

    runtimeDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/hermes/.hermes/shopping/browser-runtime";
      description = "Runtime scratch directory for the browser stack.";
    };

    displayNumber = lib.mkOption {
      type = lib.types.int;
      default = 99;
      description = "X display number used by Xvfb.";
    };

    display = lib.mkOption {
      type = lib.types.str;
      default = ":99";
      description = "DISPLAY value used by Xvfb, openbox, Chromium, and x11vnc.";
    };

    screen = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080x24";
      description = "Xvfb screen geometry and color depth.";
    };

    windowSize = lib.mkOption {
      type = lib.types.str;
      default = "1920,1080";
      description = "Initial Chromium window size.";
    };

    vncPort = lib.mkOption {
      type = lib.types.port;
      default = 5900;
      description = "Localhost-only x11vnc port.";
    };

    noVncPort = lib.mkOption {
      type = lib.types.port;
      default = 6080;
      description = "Localhost-only noVNC/websockify port to tunnel from the laptop.";
    };

    cdpPort = lib.mkOption {
      type = lib.types.port;
      default = 9222;
      description = "Localhost-only Chromium DevTools Protocol port for Playwright connectOverCDP.";
    };

    startUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://www.hepsiburada.com/";
      description = "Initial browser URL.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      chromium
      xorg.xvfb
      xorg.xdpyinfo
      openbox
      x11vnc
      novnc
      websockifyEnv
    ];

    systemd.services.hermes-headed-browser = {
      description = "Hermes headed browser stack for authenticated shopping";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        DISPLAY = cfg.display;
        HOME = toString cfg.homeDir;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = startScript;
        Restart = "on-failure";
        RestartSec = 5;
        KillMode = "control-group";
        TimeoutStopSec = 15;
        NoNewPrivileges = true;
        PrivateTmp = false;
      };
    };
  };
}
