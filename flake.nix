{
  inputs.nixpkgsModulesPath.url = "github:erikarvstedt/nixpkgs/add-modules-path";
  inputs.nixpkgsExtraContainer.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { ... }@inputs: with inputs; let
    system = "x86_64-linux";
    pkgsModulesPath = nixpkgsModulesPath.legacyPackages.${system};
    pkgsExtraContainer = nixpkgsExtraContainer.legacyPackages.${system};
    pkgs = pkgsExtraContainer;

    nixpkgsModulesPathNoPatch = pkgs.runCommand "nixpkgs" {} ''
      ${pkgs.rsync}/bin/rsync -r --chmod=a+w ${nixpkgsModulesPath}/ $out
      cd $out
      patch -p1 <${./remove-glibc-patch.patch}
    '';

    debugGlibc = pkgsModulesPath.glibc.overrideAttrs (old: rec {
      # work around `pkgs.enableDebugging` currently being broken
      NIX_CFLAGS_COMPILE = old.NIX_CFLAGS_COMPILE + " -ggdb -Og";
      # Adding debug cflags causes warnings, so don't fail on warnings
      configureFlags = old.configureFlags ++ ["--disable-werror"];
      separateDebugInfo = false;

      shellHook = ''
        . ${./lib.sh}
        export NIX_PATH=nixpkgs-modules-path=${nixpkgsModulesPath}:$NIX_PATH
        export NIX_PATH=nixpkgs-modules-path-no-patch=${nixpkgsModulesPathNoPatch}:$NIX_PATH
        export PATH=${pkgsExtraContainer.extra-container}/bin:$PATH
      '';
    });
  in {
    devShell.${system} = debugGlibc;
    packages.${system} = { inherit nixpkgsModulesPathNoPatch; };
  };
}
