{
  description = "Bebida testbed with K8s and OAR or Slurm";

  inputs = {
    #nixpkgs.url = "github:NixOS/nixpkgs/22.05";
    nixpkgs.url = "github:NixOS/nixpkgs/23.05";
    nxc.url = "git+https://gitlab.inria.fr/nixos-compose/nixos-compose.git?ref=nixpkgs-2305";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    NUR.url = "github:nix-community/NUR";
    kapack.url = "github:oar-team/nur-kapack?ref=regale";
    kapack.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nxc, NUR, kapack }:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system} = nxc.lib.compose {
        inherit nixpkgs system NUR;
        repoOverrides = { inherit kapack; };
        setup = ./setup.toml;
        compositions = ./compositions.nix;
      };
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
      devShell.${system} = (nxc.devShells.${system}.nxcShell.overrideAttrs (old: {
        buildInputs = old.buildInputs ++ [
          nixpkgs.legacyPackages.x86_64-linux.vde2
          nixpkgs.legacyPackages.x86_64-linux.qemu_kvm
        ];
      }));
    };
}
