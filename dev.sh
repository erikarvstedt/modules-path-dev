# This repo helps testing and debugging branch
# https://github.com/erikarvstedt/nixpkgs/commits/add-modules-path

# Run the commands below from within a dev shell:
nix develop

#-------------------------------------------------------
## 1. Fetch glibc source including patches from branch add-modules-path
# to ./glibc-2.33 and build glibc incrementally with output to ./build
# See ./lib.sh for details
# This function is idempotent.
build

#-------------------------------------------------------
## 2. Build a binary using the custom-built glibc
gccCustomGlibc call-getaddrinfo.c -o call-getai

# run the binary
./call-getai

# inspect syscalls in glibc
strace ./call-getai

#-------------------------------------------------------
## 3. run the binary in a container based on
# https://github.com/erikarvstedt/nixpkgs/commits/add-modules-path-no-glibc-patch
# This branch is like add-modules-path but doesn't contain the glibc patch
# so that a full system build is not triggered

# start shell in container
read -d '' tmpstr <<'EOF' || :
{
  containers.tmp = {
    extra.addressPrefix = "10.30.0";
    extra.enableWAN = true;
    bindMounts.${toString <pwd>} = {};
    config = { pkgs, config, lib, ... }: with lib; {
      networking.firewall.enable = false;
      environment.variables.PAGER = "cat";
      system.activationScripts.linkPwd = ''
        ln -sfn "${toString <pwd>}" /pwd
      '';
    };
  };
}
EOF
sudo extra-container shell -E "$tmpstr" --nixpkgs-path "<nixpkgs-modules-path-no-patch>" --run c

## execute the following commands in the container shell that just started
# run the binary built in step 1. in the container
/pwd/call-getai

# check that /run/nss-modules64-2.33/lib/libnss_mymachines.so.2 is used
strace /pwd/call-getai |& grep /run/nss-modules

# nscd is running
systemctl status nscd
# the nscd socket is not opened
strace /pwd/call-getai |& grep nscd/socket # => no match
# binaries using previous versions of glibc still use nscd
strace getent hosts localhost |& grep nscd/socket
# (exit shell here)

#-------------------------------------------------------
## 4. run a container based on branch add-modules-path
# This uses the patched glibc globally in the system.

# 4.1. Build a basic system. This can take up to 2 hours.
nix-build --out-link build/glibc-system
(import <nixpkgs-modules-path/nixos> {
  configuration = { pkgs, lib, ... }: {
    boot.isContainer = true;
    documentation.enable = false;
    # Avoid pulling in polkit -> spidermonkey -> rustc -> LLVM
    security.polkit.enable = false;
  };
}).system
EOF

# we need this further below in the container shell
nix build --out-link build/old-glibc -f '<nixpkgs-modules-path-no-patch>' glibc.bin

# 4.2 start shell in container
read -d '' tmpstr <<'EOF' || :
{
  containers.tmp = {
    extra.addressPrefix = "10.30.0";
    extra.enableWAN = true;
    bindMounts.${toString <pwd>} = {};
    config = { pkgs, config, lib, ... }: with lib; {
      networking.firewall.enable = false;
      environment.variables.PAGER = "cat";
      system.activationScripts.linkPwd = ''
        ln -sfn "${toString <pwd>}" /pwd
      '';
      # Avoid pulling in polkit -> spidermonkey -> rustc -> LLVM
      security.polkit.enable = false;
    };
  };
}
EOF
sudo extra-container shell -E "$tmpstr"  --nixpkgs-path "<nixpkgs-modules-path>" --run c

## execute the following commands in the container shell that just started
# system binaries don't use nscd
strace getent hosts localhost |& grep nscd/socket # => no match

# instead, they directly load the modules
strace getent hosts localhost |& grep /run/nss-modules

# binaries using previous versions of glibc fall back to using nscd
strace /pwd/build/old-glibc-bin/bin/getent hosts localhost |& grep nscd/socket
# (exit shell here)
