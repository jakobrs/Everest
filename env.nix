with import <nixpkgs> {};

let
  Everest = callPackage ./everest.nix {};

in stdenv.mkDerivation {
  name = "everestEnv";
  buildInputs = [ Everest ];
}
