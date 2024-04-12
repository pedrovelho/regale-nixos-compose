{ pkgs, modulesPath, ... }:
let
  nbNodes = 2;
  nbNodesStr = builtins.toString nbNodes;
in
{
  roles =
    let
      commonConfig = import ./common_config.nix { inherit pkgs modulesPath; HPCScheduler = "SLURM"; };
      slurmConfig = import ./slurm_config.nix { inherit pkgs; nbNodes = nbNodesStr; };
    in
    {
      frontend = { ... }: {
        imports = [ commonConfig slurmConfig ];
        nxc.sharedDirs."/users".server = "server";

        services.slurm.enableStools = true;
      };
      server = { ... }: {
        imports = [ commonConfig slurmConfig ];
        nxc.sharedDirs."/users".export = true;

        services.slurm.server.enable = true;
        services.slurm.dbdserver.enable = true;

        services.bebida-shaker.enable = true;

        # K3s utils
        environment.systemPackages = with pkgs; [
          pkgs.spark3
          python3Packages.py4j
          python3Packages.pyarrow
          python3Packages.dbfread
          python3Packages.pandas
          python3Packages.numpy
          python3Packages.tifffile
        ];

      };

      node = { ... }: {
        imports = [ commonConfig slurmConfig ];
        nxc.sharedDirs."/users".server = "server";

        services.slurm.client.enable = true;
      };
    };

  rolesDistribution = { node = nbNodes; };
}
