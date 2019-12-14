/*
  To use:

  1. Generate the list of dependencies in ./deps.json
     $ ./nixGenDeps.py
  2. Build Everest
     $ nix-shell env.nix
  3. Install Everest
     $ install-everest [path to Celeste installation folder]
     If no path is given, defaults to the current directory
  */

{ lib, fetchNuGet, buildDotnetPackage, mono, bash
, depsFile ? ./deps.json }:

let
  commit = lib.commitIdFromGitRepo ./.git;

  processDep = { name, version, sha256, ... }: fetchNuGet {
    baseName = name;
    inherit version sha256;

    outputFiles = ["*"];
  };

  deps = map processDep (builtins.fromJSON (builtins.readFile depsFile));

in buildDotnetPackage rec {
  baseName = "Everest";
  version = "0.0.0";
  name = "${baseName}-dev-${version}";

  src = ./.;
  #sourceRoot = ".";

  xBuildFiles = [ "Celeste.Mod.mm/Celeste.Mod.mm.csproj" "MiniInstaller/MiniInstaller.csproj" ];
  outputFiles = [ "Celeste.Mod.mm/bin/Release/*" "MiniInstaller/bin/Release/*" ];

  patchPhase = ''
    # $(SolutionDir) does not work for some reason
    substituteInPlace Celeste.Mod.mm/Celeste.Mod.mm.csproj --replace '$(SolutionDir)' ".."
    substituteInPlace MiniInstaller/MiniInstaller.csproj --replace '$(SolutionDir)' ".."

    # See c4263f8 Celeste.Mod.mm/Mod/Everest/Everest.cs line 31
    # This is normally set by Azure
    substituteInPlace Celeste.Mod.mm/Mod/Everest/Everest.cs --replace '0.0.0-dev' "0.0.0-nix-${builtins.substring 0 7 commit}"
  '';

  preBuild = ''
    # Fake nuget restore, not very elegant but it works.
    mkdir -p packages
    ${
      let
        processDepLn = pkg: "ln -sn ${pkg}/lib/dotnet/${pkg.baseName} packages/${pkg.baseName}.${pkg.version}";
      in
        builtins.concatStringsSep "\n" (builtins.map processDepLn deps)
    }
  '';

  postInstall = ''
    mv \
      $out/lib/dotnet/Everest/libMonoPosixHelper.dylib.dSYM/Contents/Resources/DWARF/libMonoPosixHelper.dylib \
      $out/lib/dotnet/Everest/libMonoPosixHelper.dylib.dSYM/Contents/Info.plist \
      $out/lib/dotnet/Everest/lib64/* \
      $out/lib/dotnet/Everest/
    if [ -f "${mono}/lib/libMonoPosixHelper.so" ]; then
      cp ${mono}/lib/libMonoPosixHelper.so $out/lib/dotnet/Everest
    fi
    rm -r $out/lib/dotnet/Everest/lib64 $out/lib/dotnet/Everest/libMonoPosixHelper.dylib.dSYM

    cat >$out/bin/install-everest <<EOF
    #! ${bash}/bin/bash

    cd "\$1"
    if ! [[ -f Celeste.exe || -f Celeste.bin.osx || -f Celeste.bin.x86_64 || -f Celeste.bin.x86 ]]; then
      echo "No Celeste executable found, refusing to install" 1>&2
      exit 1
    fi
    cp -r "$out"/lib/dotnet/Everest/* .

    exec "$out/bin/miniinstaller"
    EOF

    chmod +x $out/bin/install-everest
  '';

  verbose = true;
} // { shell = import ./shell.nix; }
