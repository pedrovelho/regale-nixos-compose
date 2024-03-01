{ lib, pkgs, config, ... }:
with lib;
let cfg = config.services.ryax-install;
in {
  options.services.ryax-install = {
    enable = mkEnableOption "ryax-install service";
    kubeconfigPath = mkOption {
      type = types.path;
      default = "/etc/bebida/kubeconfig.yaml";
    };
    ryaxConfigFile = mkOption {
      type = types.path;
      default = pkgs.writeText "values.yaml" ''
        version: 24.02.0
        clusterName: local
        imagePullPolicy: Always
        logLevel: debug
        storageClass: local-path
        monitoring:
          enabled: false
        environment: development
        tls:
          enabled: false

        datastore:
          pvcSize: 2Gi
        filestore:
          pvcSize: 5Gi
        registry:
          pvcSize: 5Gi

        traefik:
          enabled: false
        prometheus:
          enabled: false
        loki:
          enabled: true
        rabbitmq:
          values:
            metrics:
              enabled: false
            ulimitNofiles: ""
        certManager:
          enabled: false
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.ryax-install = {
      after = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        # Type = "oneshot";
        Restart = "on-failure";
        RestartSec = 1;
      };
      path = [
        pkgs.kubectl
        pkgs.gitMinimal
        pkgs.poetry
        (pkgs.wrapHelm pkgs.kubernetes-helm { plugins = [ pkgs.kubernetes-helmPlugins.helm-diff ]; })
        pkgs.helmfile
        pkgs.bash
      ];
      script = ''
        set -e
        set -x
        set -u

        export KUBECONFIG=${cfg.kubeconfigPath}

        RYAX_ADM_DIR=$(mktemp -d)
        git clone https://gitlab.com/ryax-tech/ryax/ryax-adm.git $RYAX_ADM_DIR

        cd $RYAX_ADM_DIR
        poetry install --without dev
        poetry run ryax-adm apply --values ${cfg.ryaxConfigFile} --retry 2 --suppress-diff
      '';
    };
  };
}
