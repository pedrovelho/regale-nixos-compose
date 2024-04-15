{ pkgs, modulesPath, HPCScheduler }:
let
  inherit (import "${toString modulesPath}/tests/ssh-keys.nix" pkgs) snakeOilPrivateKey snakeOilPublicKey;
  sshPrivateKey = ./secrets/ssh_key;
  sshPublicKey = ./secrets/ssh_key.pub;
in
{
  # Inject key to permit localhost ssh from bebida-shaker
  users.users.root.openssh.authorizedKeys.keys = [
    (builtins.readFile sshPublicKey)
  ];

  environment.systemPackages = [
    pkgs.python3
    pkgs.emacs
    pkgs.vim
    pkgs.cpufrequtils
    pkgs.python3Packages.clustershell
    pkgs.htop
    pkgs.tree
    pkgs.cri-tools
  ];

  environment.noXlibs = false;

  nxc.users = { names = [ "ryax" ]; prefixHome = "/users"; };

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
    text = snakeOilPublicKey;
  };
}
