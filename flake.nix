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

  outputs = { nixpkgs, hermes-agent, sops-nix, codex-cli-nix, ... }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };
      hermesAgentPackage = hermes-agent.packages.${system}.default;
      herm-tui = pkgs.callPackage ./packages/herm-tui.nix {
        inherit hermesAgentPackage;
      };
    in
    {
      packages.${system} = {
        herm-tui = herm-tui;
        default = herm-tui;
      };

      nixosConfigurations.hermesbox = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit hermes-agent codex-cli-nix herm-tui;
        };
        modules = [
          hermes-agent.nixosModules.default
          sops-nix.nixosModules.sops
          ./hosts/hermesbox/configuration.nix
        ];
      };
    };
}
