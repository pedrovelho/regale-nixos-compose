{ stdenv, mpi }:

stdenv.mkDerivation {
  name = "Light-ESP";
  version = "2.2.1";

  src = ./light-esp;

  preConfigure = ''
    export ESPHOME=$out
    export CC=${mpi}/bin/mpicc
  '';

  postInstall = ''
    cp ./runesp $out/bin
    cp ./jobmix/mkjobmix $out/bin
    mkdir $out/pm
    cp -r ./pm/* $out/pm
  '';

  meta = {
    description = "Run a fixed number of parallel jobs through a batch scheduler in the minimum elapsed time.";
    longDescription = "Usage: TODO";
  };
}
