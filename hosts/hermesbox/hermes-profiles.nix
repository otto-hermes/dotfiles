{ lib, pkgs, ... }:

{
  # Pure declarative default profile config. 
  # Specialist profiles and routing logic have been purged.
  
  environment.systemPackages = [
  ];

  system.activationScripts.hermesProfiles.text = ''
    set -euo pipefail
    # Ensure profile directories are gone.
    rm -rf /home/hermes/.hermes/profiles/*
  '';
}
