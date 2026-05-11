{ lib, pkgs, ... }:

let
  sshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7xbK04FcadV9+BFH7Zw4SOWnULsIIF9Xt6b+EXx5nvhnZVDkKerlvcM2NqpY+aIvNlXxERccgNpynxmuz9yqXYCpLjD4L1s5RZeAsR68Z26x4xt6ndGzW5KXrHp7yxPtIwo/oBw4S3JsdmuWQrCKZuabpqlsIyL4IknTDEh/p/BatkdySC5spfFqFOZxTpBWCPGug4hxICsQE9gHSIEqbN/MdYvYYTsvksBXfGPLePHUzi+f8rNNXH6ck7+RLYzw3syhxcgfJHXEmsYaQDvqOYQmzwdR+c2ZzoR3p8nk/3BEKlf0t8LkfkPrLnIHLpexgqYMUMRhupyRlkPx8mUwJ ssh-key-2026-05-01";
in
{
  imports = [
    ./hardware-configuration.nix
    ./sops-secrets.nix
    ./hermes-agent.nix
    ./himalaya.nix
    ./tailscale.nix
  ];

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

  programs.fish = {
    enable = true;
    interactiveShellInit = "set fish_greeting";
    shellAliases = {
      ll = "ls -lah";
      rebuild = "sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox";
    };
  };

  programs.bash = {
    completion.enable = true;
    shellAliases = {
      ll = "ls -lah";
      rebuild = "sudo nixos-rebuild switch --flake /home/hermes/dotfiles#hermesbox";
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
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
    openssh.authorizedKeys.keys = [ sshKey ];
  };

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
    curl
    espeak-ng
    fastfetch
    fd
    ffmpeg
    fish
    git
    htop
    jq
    neovim
    nix-output-monitor
    python3
    ripgrep
    tmux
    tree
    yazi
    wget
  ];

  services.logrotate.checkConfig = false;
  zramSwap.enable = true;

  system.stateVersion = "23.11";
}
