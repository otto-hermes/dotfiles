{
  description = "Declarative NixOS configuration for hermesbox";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    hermes-agent.url = "github:NousResearch/hermes-agent";
    sops-nix.url = "github:Mic92/sops-nix";
    codex-cli-nix = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, hermes-agent, sops-nix, codex-cli-nix, ... }: {
    nixosConfigurations.hermesbox = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {
        inherit hermes-agent codex-cli-nix;
      };
      modules = [
        hermes-agent.nixosModules.default
        sops-nix.nixosModules.sops
        ./hosts/hermesbox/configuration.nix
      ];
    };
  };
}
