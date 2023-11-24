{
  pkgs,
  modulesPath,
  nur,
  ...
}: {
  environment.variables.MELISSA_SRC = "${pkgs.nur.repos.kapack.melissa-launcher.src}";
  environment.systemPackages = [
    pkgs.nur.repos.kapack.melissa-heat-pde
    pkgs.nur.repos.kapack.melissa-launcher
  ];
  security.pam.loginLimits = [
    {
      domain = "*";
      item = "memlock";
      type = "-";
      value = "unlimited";
    }
    {
      domain = "*";
      item = "stack";
      type = "-";
      value = "unlimited";
    }
  ];
}
