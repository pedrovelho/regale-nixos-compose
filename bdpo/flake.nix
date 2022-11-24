{
  description = "BDPO";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/22.05";
    nxc.url = "git+https://gitlab.inria.fr/nixos-compose/nixos-compose.git";
    nxc.inputs.nixpkgs.follows = "nixpkgs";
    NUR.url = "github:nix-community/NUR";
    kapack.url = "github:oar-team/nur-kapack?ref=regale";
    kapack.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nxc, NUR, kapack}:
    let
      system = "x86_64-linux";
    in {
      packages.${system} = nxc.lib.compose {
        inherit nixpkgs system NUR;
        repoOverrides = { inherit kapack; };
        setup = ./setup.toml;
        composition = ./composition.nix;
        overlays = [
           (self: super: {
             kernel = super.pkgs.linuxPackagesFor (super.pkgs.linux.override
               {
                 structuredExtraConfig = with super.lib.kernel; {
                   X86_ACPI_CPUFREQ = yes;
                   X86_INTEL_PSTATE = no;
                 };
                 ignoreConfigErrors = true;
               });
           })
        ];

      };
      
      devShell.${system} = nxc.devShells.${system}.nxcShell;
    };
}

