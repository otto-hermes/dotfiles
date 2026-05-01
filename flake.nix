{
  description = "Declarative NixOS configuration for hermesbox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };

  outputs = { nixpkgs, ... }: {
    nixosConfigurations.hermesbox = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./hosts/hermesbox/configuration.nix
      ];
    };
  };
}
