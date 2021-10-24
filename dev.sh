# This repo helps testing and debugging branch
# https://github.com/erikarvstedt/nixpkgs/commits/add-modules-path-3

# Run the commands below from within a dev shell:
nix develop

#-------------------------------------------------------
## 1. Fetch glibc source including patches from branch add-modules-path-3
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
## 3. run a container based on branch add-modules-path-3
# This uses the patched glibc globally in the system.

read -d '' containerSrc <<'EOF' || :
{
  containers.tmp = {
    extra.addressPrefix = "10.30.0";
    extra.enableWAN = true;
    bindMounts.${toString <pwd>} = {};
    config = { pkgs, config, lib, ... }: with lib; {
      networking.firewall.enable = false;
      documentation.enable = false;
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

# 3.2 Build the container system. This can take up to 2 hours.
extra-container build -E "$containerSrc" --nixpkgs-path "<nixpkgs-modules-path>"
# With external builder
extra-container build -E "$containerSrc" --nixpkgs-path "<nixpkgs-modules-path>" --build-args --max-jobs 0 --builders 'ssh://mybuilder - - 15 - big-parallel'

# 3.3 Start shell in container
sudo extra-container shell -E "$containerSrc" --nixpkgs-path "<nixpkgs-modules-path>" --run c

## Execute the following commands in the container shell that just started:

getent hosts

# nscd is running and used by glibc
systemctl status nscd
strace getent hosts localhost |& grep nscd

systemctl stop nscd
# now /run/nss-modules-{hash}/lib/libnss_mymachines.so.2 is used directly
strace getent hosts localhost |& grep /run/nss-modules
# (exit shell here)
