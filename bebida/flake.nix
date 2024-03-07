{
  description = "Bebida testbed with K8s and OAR or Slurm";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/23.05";
    nxc.url = "git+https://gitlab.inria.fr/nixos-compose/nixos-compose.git"; #?ref=nixpkgs-2305";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    NUR.url = "github:nix-community/NUR";
    kapack.url = "github:oar-team/nur-kapack?ref=regale";
    kapack.inputs.nixpkgs.follows = "nixpkgs";
    bebidaOptimizer.url = "github:RyaxTech/bebida-optimization-service";
    # bebidaOptimizer.url = "/home/mmercier/Projects/bebida-optimization-service";
  };

  outputs = { self, nixpkgs, nxc, NUR, kapack, bebidaOptimizer }:
    let
      system = "x86_64-linux";
    in
    {
      packages.${system} = nxc.lib.compose {
        inherit nixpkgs system NUR;
        repoOverrides = { inherit kapack; };
        extraConfigurations = [ bebidaOptimizer.nixosModules.default ];
        #overlays = [
        #   (self: super: {
        #     bebidaShaker = bebidaOptimizer.packages.${system}.bebida-shaker;
        #   })
        #];
        setup = ./setup.toml;
        compositions = ./compositions.nix;
      };
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;
      devShell.${system} = nxc.devShells.${system}.nxcShellFull;
      lightESP = nixpkgs.legacyPackages.x86_64-linux.callPackage ./pkgs/light-ESP.nix {};
    };
}
