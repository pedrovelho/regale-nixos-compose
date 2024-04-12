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

  testScript = ''
    start_all()

    # Make sure DBD is up after DB initialzation
    with subtest("can_start_slurmdbd"):
        dbd.succeed("systemctl restart slurmdbd")
        dbd.wait_for_unit("slurmdbd.service")
        dbd.wait_for_open_port(6819)

    # there needs to be an entry for the current
    # cluster in the database before slurmctld is restarted
    with subtest("add_account"):
        server.succeed("sacctmgr -i add cluster default")
        # check for cluster entry
        server.succeed("sacctmgr list cluster | awk '{ print $1 }' | grep default")

    with subtest("can_start_slurmctld"):
        server.succeed("systemctl restart slurmctld")
        server.wait_for_unit("slurmctld.service")

    with subtest("can_start_slurmd"):
            node1.succeed("systemctl restart slurmd.service")
            node1.wait_for_unit("slurmd")
  '';
}
