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

        # Facet dependencies
        environment.systemPackages = with pkgs; [
          pkgs.spark3
          pkgs.gitMinimal
          python3Packages.py4j
          python3Packages.pyarrow
          python3Packages.dbfread
          python3Packages.pandas
          python3Packages.numpy
          python3Packages.tifffile
        ];

        system.activationScripts.ryax-user-init = ''
          mkdir -p /users/ryax/.ssh
          echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDX8e0uKbhUu6MWGnbMzq+kdGOVWSn0mPeD0VeQxn5QbWdmUGVyRe8IoNlM1TpfFHA0ZdnYNTT5c4CT+qyPikMVr1IUlH0Rup2/ieIWA8ljUwRX9o3Kw1GN0xc+mQxr3AAAjA8CwHxFX2bih/xacQz85hQguUofRdzlpfJ1fZoB+Dw/Rpd4aUiSNNGt+NYmKrVRvMJhFsQkQm+TzI6P8WP6GPegdS2jINUzwUC0jEWHQz5fs5c6jVDOPBXE8/qHusu1SHC6FlhZjyOXCmMYAPn9v11iLCn3Z2C2wufBU9sHztHHYU2p/a4v23LN+Esn+l9+gYwUQ68t9oIBmG8K2tu9MwGNlCMziJRx6G2JHiQNoA5Gu5zTbJVLEYFF00upoFGEDNObLzt0gQugkiTd4kvyC72Up0DM+qnVzIfhnDg7uddpYxmal0koOwmeuqyYUz75Ti+hOZ8VLkJ90C+KD8UzZp7O7++5hefXHYpx89fgs4tbv5W0KOUnxah6rX4T1ms= slurmuser@ryax" >> /users/ryax/.ssh/authorized_keys
          cat > /users/ryax/requirements.txt <<EOF
          pyspark==3.2.1
          numpy==1.22.3
          dbfread==2.0.7
          pandas==1.3.4
          datar==0.8.1
          tifffile==2022.5.4
          pyarrow==10.0.0
          EOF
          python -m venv .venv
          source .venv/bin/activate
          pip install -r requirements.txt
          cd /users/ryax
          git clone https://gitlab.com/ryax-tech/projects/2022/regale.git
        '';

      };

      node = { ... }: {
        imports = [ commonConfig slurmConfig ];
        nxc.sharedDirs."/users".server = "server";

        services.slurm.client.enable = true;
      };
    };

  rolesDistribution = { node = nbNodes; };
}
