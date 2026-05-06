{
  description = "Declarative NixOS configuration for hermesbox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    hermes-agent.url = "github:NousResearch/hermes-agent";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { nixpkgs, hermes-agent, sops-nix, ... }: {
    nixosConfigurations.hermesbox = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {
        inherit hermes-agent;
      };
      modules = [
        hermes-agent.nixosModules.default
        sops-nix.nixosModules.sops
        ./hosts/hermesbox/configuration.nix
      ];
    };
  };
}
