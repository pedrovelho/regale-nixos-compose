{ stdenv, mpi }:

stdenv.mkDerivation {
  name = "Light-ESP";
  version = "2.2.1";

  src =  ./light-esp;

  preConfigure = ''
    export ESPHOME=$out
    export CC=${mpi}/bin/mpicc
  '';

  postInstall = ''
    cp ./runesp $out/bin
    cp ./jobmix/mkjobmix $out/bin
    mkdir $out/pm
    cp ./pm/OAR-bebida.pm $out/pm
  '';
}
