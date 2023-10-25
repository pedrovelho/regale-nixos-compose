{
  pkgs,
  modulesPath,
  nur,
  flavour,
}: let
  inherit
    (import "${toString modulesPath}/tests/ssh-keys.nix" pkgs)
    snakeOilPrivateKey
    snakeOilPublicKey
    ;
  scripts = import scripts/scripts.nix {inherit pkgs;};
in {
  imports = [nur.repos.kapack.modules.oar];

  environment.variables.OMPI_ALLOW_RUN_AS_ROOT = "1";
  environment.variables.OMPI_ALLOW_RUN_AS_ROOT_CONFIRM = "1";

  environment.systemPackages = [
    pkgs.python3 pkgs.nano pkgs.vim
    pkgs.nur.repos.kapack.oar 
    pkgs.jq

    pkgs.nano
    pkgs.mariadb
    pkgs.cpufrequtils

    pkgs.nur.repos.kapack.npb
    pkgs.nur.repos.kapack.openmpi
    pkgs.nur.repos.kapack.ucx
    (pkgs.hpl.override { mpi = pkgs.nur.repos.kapack.openmpi; })

    pkgs.taktuk

    scripts.wait_db
    scripts.add_resources
  ];

  networking.firewall.enable = false;

  users.users.user1 = {isNormalUser = true;};
  users.users.user2 = {isNormalUser = true;};

  # Service dedicated to the gros cluster at nancy
  # that has nodes configured with two network interfaces.
  # The stage 1 configures both interface with ip in the same network, 
  # leading openmpi to not being able to start jobs.
  systemd.services.shutdown-eno2np1 = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" "network-online.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
  	  ${pkgs.iproute2}/bin/ip link set dev eno2np1 down
    '';
  };

  systemd.services.oar-cgroup = {
    enable = flavour.name == "docker";
    serviceConfig = {
      ExecStart = "${scripts.prepare_cgroup} init";
      ExecStop = "${scripts.prepare_cgroup} clean";
      KillMode = "process";
      RemainAfterExit = "on";
    };
    wantedBy = ["network.target"];
    before = ["network.target"];
    serviceConfig.Type = "oneshot";
  };

  services.openssh.extraConfig = ''
    AuthorizedKeysCommand /usr/bin/sss_ssh_authorizedkeys
    AuthorizedKeysCommandUser nobody
  '';

  environment.etc."privkey.snakeoil" = {
    mode = "0600";
    source = snakeOilPrivateKey;
  };
  environment.etc."pubkey.snakeoil" = {
    mode = "0600";
    #source = snakeOilPublicKey;
    text = snakeOilPublicKey;
  };

  environment.etc."oar-dbpassword".text = ''
    # DataBase user name
    DB_BASE_LOGIN="oar"

    # DataBase user password
    DB_BASE_PASSWD="oar"

    # DataBase read only user name
    DB_BASE_LOGIN_RO="oar_ro"

    # DataBase read only user password
    DB_BASE_PASSWD_RO="oar_ro"
  '';

  environment.etc."oar-quotas.json" = {
    text = ''
      {
        "quotas": {
        }
      }
    '';
    mode = "0777";
  };

  services.oar = {
    extraConfig = {
      LOG_LEVEL = "3";
      HIERARCHY_LABELS = "resource_id,network_address,cpuset";
      QUOTAS = "yes";
      QUOTAS_CONF_FILE = "/etc/oar-quotas.json";
    };

    # oar db passwords
    database = {
      host = "server";
      passwordFile = "/etc/oar-dbpassword";
      initPath = [pkgs.util-linux pkgs.gawk pkgs.jq scripts.wait_db scripts.add_resources];
      postInitCommands = ''
        num_cores=$(( $(lscpu | awk '/^Socket\(s\)/{ print $2 }') * $(lscpu | awk '/^Core\(s\) per socket/{ print $4 }') ))
        echo $num_cores > /etc/num_cores

        if [[ -f /etc/nxc/deployment-hosts ]]; then
          num_nodes=$(grep node /etc/nxc/deployment-hosts | wc -l)
        else
          num_nodes=$(jq -r '[.nodes[] | select(contains("node"))]| length' /etc/nxc/deployment.json)
        fi
        echo $num_nodes > /etc/num_nodes

        wait_db

        add_resources $num_nodes $num_cores
      '';
    };
    server.host = "server";
    privateKeyFile = "/etc/privkey.snakeoil";
    publicKeyFile = "/etc/pubkey.snakeoil";
  };
}
