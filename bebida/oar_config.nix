{ pkgs, nur }:
let
  scripts = import ./scripts/scripts.nix { inherit pkgs; };
in
{
  imports = [
    nur.repos.kapack.modules.oar
  ];
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

  environment.etc."oar/bebida_prolog.sh".source = scripts.bebida_prolog;
  environment.etc."oar/bebida_epilog.sh".source = scripts.bebida_epilog;

  services.oar = {
    # oar db passwords
    database = {
      host = "server";
      passwordFile = "/etc/oar-dbpassword";
      initPath = [ pkgs.util-linux pkgs.gawk pkgs.jq scripts.add_resources ];
      postInitCommands = scripts.oar_db_postInitCommands;
    };
    server.host = "server";
    privateKeyFile = "/etc/privkey.snakeoil";
    publicKeyFile = "/etc/pubkey.snakeoil";
    extraConfig = {
      SERVER_PROLOGUE_EXEC_FILE = "/etc/oar/bebida_prolog.sh";
      SERVER_EPILOGUE_EXEC_FILE = "/etc/oar/bebida_epilog.sh";
    };
  };
}
