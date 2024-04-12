{
  description = "Slurm and facet aware cluster";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.11";
    nxc.url = "git+https://gitlab.inria.fr/nixos-compose/nixos-compose.git";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    NUR.url = "github:nix-community/NUR";
  };

  outputs = { self, nixpkgs, nxc, NUR }:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system} = nxc.lib.compose {
        inherit nixpkgs system NUR;
        setup = ./setup.toml;
        composition = ./composition.nix;
      };
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
      devShell.${system} = nxc.devShells.${system}.nxcShellFull;
    };
}
