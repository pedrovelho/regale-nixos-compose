{ pkgs, modulesPath, nur, helpers, flavour, ... }: {
  roles =
    let
      commonConfig = import ./common_config.nix { inherit pkgs modulesPath; HPCScheduler = "OAR"; };
      oarConfig = import ./oar_config.nix { inherit pkgs nur flavour modulesPath; };
      demoConfig = import ./demo.nix { };
      tokenFile = pkgs.writeText "token" "p@s$w0rd";
    in
    {
      frontend = { ... }: {
        imports = [ commonConfig oarConfig ];
        nxc.sharedDirs."/users".server = "server";

        services.oar.client.enable = true;
        services.oar.web.enable = true;
        services.oar.web.drawgantt.enable = true;
        services.oar.web.monika.enable = true;
      };

      server = { ... }: {
        imports = [ commonConfig oarConfig demoConfig ]; # ./ryax.nix ];
        # Make this machine an NFS server for users homes
        nxc.sharedDirs."/users".export = true;

        services.oar.server.enable = true;
        services.oar.dbserver.enable = true;

        services.bebida-shaker.enable = true;

        # utils
        environment.systemPackages = with pkgs; [
          gzip
          jq
          kubectl
          # HPC Workload generator
          (callPackage ./pkgs/light-ESP.nix { })
        ];

        system.activationScripts.k3s-config = ''
          SERVER=$( grep server /etc/nxc/deployment-hosts | ${pkgs.gawk}/bin/awk '{ print $1 }')
          echo 'bind-address: "'$SERVER'"' > /etc/k3s.yaml
          echo 'node-external-ip: "'$SERVER'"' >> /etc/k3s.yaml
        '';

        # services.ryax-install.enable = true;

        services.k3s = {
          inherit tokenFile;
          enable = true;
          role = "server";
          configPath = "/etc/k3s.yaml";
          environmentFile = pkgs.writeText "k3s-export" ''
            K3S_KUBECONFIG_OUTPUT=/etc/bebida/kubeconfig.yaml
            K3S_KUBECONFIG_MODE=666
          '';
        };
      };

      node = { ... }: {
        imports = [ commonConfig oarConfig ];
        nxc.sharedDirs."/users".server = "server";

        services.oar.node.enable = true;

        services.k3s = {
          inherit tokenFile;
          enable = true;
          role = "agent";
          serverAddr = "https://server:6443";
          # Add a taint on Bebida nodes to avoid normal pod to be schedule here
          # Pods need to have the folowing toleration to be schedule on this pod
          #
          #   tolerations:
          #   - key: "bebida"
          #     operator: "Exists"
          #     effect: "NoSchedule"
          extraFlags = "--node-taint=bebida=hpc:NoSchedule --node-label=bebida=node";
        };
      };
    };

  rolesDistribution = { node = 2; };

  testScript = ''
    import os

    start_all()
    log.info("=== Environment vars are: \n" + str(os.environ))

    server.wait_for_unit('oar-server.service')
    # Submit job with script under user1
    frontend.succeed('su - user1 -c "oarsub -l nodes=2 \"hostname\""')

    # Wait output job file
    frontend.wait_for_file('/users/user1/OAR.1.stdout')

    # Check job's final state
    frontend.succeed("oarstat -j 1 -s | grep Terminated")

    frontend.succeed('su - user1 -c "oarsub -l nodes=2,walltime=1 \"sleep 60\""')
    frontend.succeed('su - user1 -c "oarsub -l nodes=1,walltime=3 \"sleep 180\""')
    frontend.succeed('su - user1 -c "oarsub -l nodes=1,walltime=2 \"sleep 120\""')

    frontend.succeed('curl http://localhost/drawgantt/')

    server.wait_for_unit('k3s.service')
    server.wait_until_succeeds('k3s kubectl get nodes | grep Ready', timeout=10)
    # This can take some time depending on your network connection
    server.wait_until_succeeds('k3s kubectl get pods -A | grep Running', timeout=90)

    server.succeed('k3s kubectl apply -f /etc/demo/pod-sleep-100.yml')
    server.wait_until_succeeds('k3s kubectl get pods | grep Running', timeout=60)

    server.wait_for_unit('ryax-install.service')
    server.succeed('curl http://localhost/app/')
    log("🚀 BeBiDa with OAR, K3s and Ryax is up and running!")
  '';
}
