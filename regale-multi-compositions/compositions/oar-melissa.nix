{
  pkgs,
  modulesPath,
  nur,
  helpers,
  setup,
  flavour,
  ...
}: {
  dockerPorts.frontend = ["8443:443" "8000:80"];

  roles = let
    oarConfig = import ../lib/oar_config.nix {inherit pkgs modulesPath nur flavour;};
    commonConfig = import ../lib/common.nix {inherit pkgs modulesPath nur flavour;};
    melissa = import ../lib/melissa.nix {};
  in {
    frontend = {...}: {
      imports = [commonConfig oarConfig melissa];
      nxc.sharedDirs."/users".server = "server";

      services.oar.client.enable = true;
    };
    server = {...}: {
      imports = [commonConfig oarConfig melissa];
      nxc.sharedDirs."/users".export = true;

      services.oar.server.enable = true;
      services.oar.dbserver.enable = true;
    };
    node = {...}: {
      imports = [commonConfig oarConfig melissa];
      nxc.sharedDirs."/users".server = "server";

      services.oar.node.enable = true;
    };
  };

  rolesDistribution = {node = 2;};

  testScript = ''
    # Submit job with script under user1
  '';
}
