{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.nixpkgsModulesPath.url = "git+file:///home/main/d/nix-dev/nixpkgs?ref=add-modules-path-3";

  outputs = { ... }@inputs: with inputs; let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    pkgsModulesPath = nixpkgsModulesPath.legacyPackages.${system};

    debugGlibc = pkgsModulesPath.glibc.overrideAttrs (old: rec {
      # work around `pkgs.enableDebugging` currently being broken
      NIX_CFLAGS_COMPILE = old.NIX_CFLAGS_COMPILE + " -ggdb -Og";
      # Adding debug cflags causes warnings, so don't fail on warnings
      configureFlags = old.configureFlags ++ ["--disable-werror"];
      separateDebugInfo = false;

      shellHook = ''
        . ${./lib.sh}
        export NIX_PATH=nixpkgs=${nixpkgs}:nixpkgs-modules-path=${nixpkgsModulesPath}:$NIX_PATH
        export PATH=${pkgs.extra-container}/bin:$PATH
      '';
    });
  in {
    devShell.${system} = debugGlibc;
    defaultPackage.${system} = nixpkgsModulesPathNoPatch;
  };
}
