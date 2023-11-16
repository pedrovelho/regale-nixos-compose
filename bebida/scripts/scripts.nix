{ pkgs }:
{

  add_resources =
    pkgs.writers.writePython3Bin "add_resources" {
      libraries = [pkgs.nur.repos.kapack.oar];
    } ''
      from oar.lib.resource_handling import resources_creation
      from oar.lib.globals import init_and_get_session
      import sys

      session = init_and_get_session()

      resources_creation(session, "node", int(sys.argv[1]), int(sys.argv[2]))
    '';

  wait_db =
    pkgs.writers.writePython3Bin "wait_db" {
      libraries = [pkgs.nur.repos.kapack.oar];
    } ''
      from oar.lib.tools import get_date
      from oar.lib.globals import init_and_get_session
      import time
      r = True
      n_try = 10000


      session = None
      while n_try > 0 and r:
          n_try = n_try - 1
          try:
              session = init_and_get_session()
              print(get_date(session))  # date took from db (test connection)
              r = False
          except Exception:
              print("DB is not ready")
              time.sleep(0.25)
    '';

  bebida_prolog = pkgs.writeShellScript "bebida_prolog"
    ''
      export OAR_JOB_ID=$1
      export PATH=$PATH:/run/current-system/sw/bin:/run/wrappers/bin
      (
      echo Enter BEBIDA prolog
      printenv
      id
      for node in $(oarstat -J -j "$OAR_JOB_ID" -p | jq ".[\"$OAR_JOB_ID\"][] | .network_address" -r)
      do
        echo == Removing node $node
        oardodo kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml drain --force --grace-period=5 --ignore-daemonsets --delete-emptydir-data --timeout=15s $node
        echo == Removed node $node
      done
      ) > /tmp/oar-''${OAR_JOB_ID}-prolog-logs 2> /tmp/oar-''${OAR_JOB_ID}-prolog-logs
    '';
  bebida_epilog = pkgs.writeShellScript "bebida_epilog"
    ''
      export OAR_JOB_ID=$1
      export PATH=$PATH:/run/current-system/sw/bin:/run/wrappers/bin
      (
      echo BEBIDA epilog
      printenv
      id
      for node in $(oarstat -J -j "$OAR_JOB_ID" -p | jq ".[\"$OAR_JOB_ID\"][] | .network_address" -r)
      do
        echo == Adding node $node
        oardodo kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml uncordon $node
        echo == Added node $node
      done
      ) > /tmp/oar-''${OAR_JOB_ID}-epilog-logs 2> /tmp/oar-''${OAR_JOB_ID}-epilog-logs
    '';
}
