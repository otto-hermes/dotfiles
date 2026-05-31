{ lib, pkgs, codex-cli-nix, herm-tui, ... }:

let
  sshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7xbK04FcadV9+BFH7Zw4SOWnULsIIF9Xt6b+EXx5nvhnZVDkKerlvcM2NqpY+aIvNlXxERccgNpynxmuz9yqXYCpLjD4L1s5RZeAsR68Z26x4xt6ndGzW5KXrHp7yxPtIwo/oBw4S3JsdmuWQrCKZuabpqlsIyL4IknTDEh/p/BatkdySC5spfFqFOZxTpBWCPGug4hxICsQE9gHSIEqbN/MdYvYYTsvksBXfGPLePHUzi+f8rNNXH6ck7+RLYzw3syhxcgfJHXEmsYaQDvqOYQmzwdR+c2ZzoR3p8nk/3BEKlf0t8LkfkPrLnIHLpexgqYMUMRhupyRlkPx8mUwJ ssh-key-2026-05-01";

  updateUiComponents = pkgs.writeShellApplication {
    name = "update-ui-components";
    runtimeInputs = with pkgs; [ nodejs python3 git nix-prefetch-github nix ];
    text = ''
      exec /home/hermes/dotfiles/hosts/hermesbox/scripts/update-ui-components.py "$@"
    '';
  };
in
{
  imports = [
    ./hardware-configuration.nix
    ./sops-secrets.nix
    ./hermes-agent.nix
    ./hermes-dashboards.nix
    ./hermes-maintenance.nix
    ./himalaya.nix
    ./tailscale.nix
    ./nginx.nix
    ./modules/hermes-headed-browser.nix
  ];

  services.hermes-headed-browser.enable = true;

  boot.tmp.cleanOnBoot = true;

  documentation.man.generateCaches = false;

  programs.mosh.enable = true;
  programs.nix-ld.enable = true;

  networking.hostName = "hermesbox";
  networking.useDHCP = lib.mkDefault true;

  time.timeZone = "Europe/Istanbul";

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nix.gc = {
    automatic = true;
    dates = "03:15";
    options = "--delete-older-than 4d";
  };

  nix.settings.auto-optimise-store = true;
  nix.settings.min-free = 5 * 1024 * 1024 * 1024;
  nix.settings.max-free = 10 * 1024 * 1024 * 1024;

  boot.loader.grub.configurationLimit = 5;

  programs.fish = {
    enable = true;
    interactiveShellInit = "set fish_greeting";
    shellAliases = {
      ll = "ls -lah";
      rebuild = "sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox";
      wiki-index = "/home/hermes/.hermes/scripts/wiki-index.py";
      wiki-query = "/home/hermes/.hermes/scripts/wiki-query.py";
    };
  };

  programs.bash = {
    completion.enable = true;
    shellAliases = {
      ll = "ls -lah";
      rebuild = "sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox";
      wiki-index = "/home/hermes/.hermes/scripts/wiki-index.py";
      wiki-query = "/home/hermes/.hermes/scripts/wiki-query.py";
    };
  };

  programs.tmux = {
    enable = true;
    extraConfig = ''
      # Hermes TUI runs in raw-mode alternate screen. Mouse mode lets wheel
      # events reach Hermes instead of tmux/terminal translating them into
      # plain Up/Down, which only recalls prompt history.
      set -g mouse on
      set -g extended-keys on
      set -as terminal-features 'xterm*:extkeys,screen*:extkeys,tmux*:extkeys'
    '';
  };

  # Keep fish installed for explicit interactive use (`fish`), but make bash
  # the default/login shell for automation and service-account sessions.
  users.defaultUserShell = pkgs.bashInteractive;
  users.mutableUsers = false;

  users.users.root = {
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [ sshKey ];
  };

  users.users.hermes = {
    isNormalUser = true;
    description = "Hermes agent operator";
    extraGroups = [ "wheel" "hermes" ];
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [ sshKey ];
  };

  users.groups.hermes = { };

  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  environment.systemPackages = with pkgs; [
    btop
    chromium
    (codex-cli-nix.packages.${pkgs.system}.codex)
    curl
    espeak-ng
    fastfetch
    fd
    ffmpeg
    fish
    git
    htop
    herm-tui
    jq
    updateUiComponents
    neovim
    nix-output-monitor
    python3
    ripgrep
    tmux
    tree
    wget
    yazi
    yt-dlp
  ];

  services.logrotate.checkConfig = false;
  zramSwap.enable = true;

  system.stateVersion = "23.11";
}
