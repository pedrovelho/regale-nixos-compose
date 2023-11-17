{ pkgs, nbNodes }:
let
  passFile = pkgs.writeText "dbdpassword" "password123";
in
{
  services.slurm = {
    controlMachine = "server";
    nodeName = [ "node[1-${nbNodes}] CPUs=1 State=UNKNOWN" ];
    partitionName = [
      "DEFAULT Nodes=node[1-${nbNodes}] Default=YES State=UP DefaultTime=60"
      "bebida Nodes=node[1-${nbNodes}] Default=YES MaxTime=INFINITE"
    ];
    extraConfig = ''
      # BEBIDA
      PrologSlurmctld=/etc/bebida/master-prolog.sh
      EpilogSlurmctld=/etc/bebida/master-epilog.sh
      PrologFlags=Alloc
    '';
  };
  environment.etc."bebida/master-prolog.sh".source = ./scripts/master-prolog.sh;
  environment.etc."bebida/master-epilog.sh".source = ./scripts/master-epilog.sh;

  environment.systemPackages = [
    # Required for the master prolog and epilog
    pkgs.coreutils
  ];

  # Avoid error about xauth missing...
  services.openssh.settings.X11Forwarding = false;
  services.slurm.dbdserver = {
    dbdHost = "server";
    storagePassFile = "${passFile}";
  };
  services.mysql = {
    enable = true;
    package = pkgs.mariadb;
    initialScript = pkgs.writeText "mysql-init.sql" ''
      CREATE USER 'slurm'@'localhost' IDENTIFIED BY 'password123';
      GRANT ALL PRIVILEGES ON slurm_acct_db.* TO 'slurm'@'localhost';
    '';
    ensureDatabases = [ "slurm_acct_db" ];
    ensureUsers = [{
      ensurePermissions = { "slurm_acct_db.*" = "ALL PRIVILEGES"; };
      name = "slurm";
    }];
    settings.mysqld = {
      # recommendations from: https://slurm.schedmd.com/accounting.html#mysql-configuration
      innodb_buffer_pool_size = "1024M";
      innodb_log_file_size = "64M";
      innodb_lock_wait_timeout = 900;
    };
  };

  systemd.services.slurmdbd.serviceConfig = {
    Restart = "on-failure";
    RestartSec = 3;
  };
  systemd.services.slurmctld.serviceConfig = {
    Restart = "on-failure";
    RestartSec = 3;
  };

  systemd.tmpfiles.rules = [
    "f /etc/munge/munge.key 0400 munge munge - mungeverryweakkeybuteasytointegratoinatest"
  ];
  networking.firewall.enable = false;

}
