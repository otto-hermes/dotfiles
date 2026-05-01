{
  description = "Declarative NixOS configuration for hermesbox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  outputs = { nixpkgs, hermes-agent, ... }: {
    nixosConfigurations.hermesbox = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        hermes-agent.nixosModules.default
        ./hosts/hermesbox/configuration.nix
      ];
    };
  };
}
