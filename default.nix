{ pkgs ? import <nixpkgs> {} }:

pkgs.callPackage ./everest.nix {}
