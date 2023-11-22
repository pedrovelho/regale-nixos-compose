{
  pkgs,
  modulesPath,
  nur,
  flavour,
}: {
  imports = [];

  environment.variables.OMPI_ALLOW_RUN_AS_ROOT = "1";
  environment.variables.OMPI_ALLOW_RUN_AS_ROOT_CONFIRM = "1";

  environment.systemPackages = [
    pkgs.nur.repos.kapack.regale-library

    pkgs.nur.repos.kapack.npb
    pkgs.openmpi
  ];

  # Service dedicated to the gros cluster at nancy
  # that has nodes configured with two network interfaces.
  # The stage 1 configures both interface with ip in the same network,
  # leading openmpi to not being able to start jobs.
  # In case you are not on the cluster, the serviceshould shust fail. You can ignore it.
  systemd.services.shutdown-eno2np1 = {
    after = ["network.target"];
    wantedBy = ["multi-user.target" "network-online.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      ${pkgs.iproute2}/bin/ip link set dev eno2np1 down
    '';
  };
}
