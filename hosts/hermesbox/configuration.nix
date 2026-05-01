{ lib, pkgs, ... }:

let
  sshKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7xbK04FcadV9+BFH7Zw4SOWnULsIIF9Xt6b+EXx5nvhnZVDkKerlvcM2NqpY+aIvNlXxERccgNpynxmuz9yqXYCpLjD4L1s5RZeAsR68Z26x4xt6ndGzW5KXrHp7yxPtIwo/oBw4S3JsdmuWQrCKZuabpqlsIyL4IknTDEh/p/BatkdySC5spfFqFOZxTpBWCPGug4hxICsQE9gHSIEqbN/MdYvYYTsvksBXfGPLePHUzi+f8rNNXH6ck7+RLYzw3syhxcgfJHXEmsYaQDvqOYQmzwdR+c2ZzoR3p8nk/3BEKlf0t8LkfkPrLnIHLpexgqYMUMRhupyRlkPx8mUwJ ssh-key-2026-05-01";
in
{
  imports = [
    ./hardware-configuration.nix
    ./hermes-agent.nix
  ];

  boot.tmp.cleanOnBoot = true;

  documentation.man.generateCaches = false;

  networking.hostName = "hermesbox";
  networking.useDHCP = lib.mkDefault true;

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

  users.defaultUserShell = pkgs.fish;
  users.mutableUsers = false;

  users.users.root = {
    shell = pkgs.fish;
    openssh.authorizedKeys.keys = [ sshKey ];
  };

  users.users.hermes = {
    isNormalUser = true;
    description = "Hermes agent operator";
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
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
    curl
    fd
    fastfetch
    fish
    git
    htop
    jq
    neovim
    nix-output-monitor
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
