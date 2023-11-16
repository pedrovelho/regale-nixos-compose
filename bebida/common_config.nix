{ pkgs, modulesPath }:
let
  inherit (import "${toString modulesPath}/tests/ssh-keys.nix" pkgs)
    snakeOilPrivateKey snakeOilPublicKey;
in
{
  environment.systemPackages = [
    pkgs.python3
    pkgs.vim
    pkgs.cpufrequtils
    pkgs.python3Packages.clustershell
    pkgs.htop
    pkgs.tree
  ];

  environment.shellAliases = {
    k = "k3s kubectl";
    kgp = "k3s kubectl get pods -A";
  };

  # Allow root yo use open-mpi
  environment.variables.OMPI_ALLOW_RUN_AS_ROOT = "1";
  environment.variables.OMPI_ALLOW_RUN_AS_ROOT_CONFIRM = "1";

  nxc.users = { names = [ "user1" "user2" ]; prefixHome = "/users"; };

  security.pam.loginLimits = [
    { domain = "*"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "*"; item = "stack"; type = "-"; value = "unlimited"; }
  ];

  environment.etc."privkey.snakeoil" = {
    mode = "0600";
    source = snakeOilPrivateKey;
  };

  environment.etc."pubkey.snakeoil" = {
    mode = "0600";
    #source = snakeOilPublicKey;
    text = snakeOilPublicKey;
  };
}
