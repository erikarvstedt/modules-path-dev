export rootDir=$PWD
export buildDir=$rootDir/build

# Extract glibc source of erikarvstedt/nixpkgs/add-modules-path
# to ./glibc-2.33/
createSrc() {(
  set -eo pipefail
  unpackPhase
  cd "${sourceRoot:-.}"
  git init
  git add .
  git commit -m "init at glibc-2.33" >/dev/null
  patchPhase || true
  git add .
  git commit -m $'apply nixpkgs patches\n\nApply patchPhase of pkgs.glibc'
)}

# Incrementally build glibc to ./build with debugging enabled.
# This takes <10 min on a desktop system
build() {(
  set -eo pipefail

  sourceRoot=glibc-2.33

  if [[ ! -e $sourceRoot ]]; then
    createSrc
  fi

  if [[ ! -e build/ ]]; then
    (cd $sourceRoot; configurePhase)
  fi

  (cd build; buildPhase)
)}

gccCustomGlibc() {
  gcc -Wl,--rpath="$buildDir" \
      -Wl,--dynamic-linker="$buildDir/elf/ld.so" \
      "$@"
}
