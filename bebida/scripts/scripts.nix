{ pkgs }:
{

  add_resources =
    pkgs.writers.writePython3Bin "add_resources"
      {
        libraries = [ pkgs.nur.repos.kapack.oar ];
      } ''
      from oar.lib.resource_handling import resources_creation
      from oar.lib.globals import init_and_get_session
      import sys

      session = init_and_get_session()

      resources_creation(session, "node", int(sys.argv[1]), int(sys.argv[2]))
    '';

  wait_db =
    pkgs.writers.writePython3Bin "wait_db"
      {
        libraries = [ pkgs.nur.repos.kapack.oar ];
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

}
