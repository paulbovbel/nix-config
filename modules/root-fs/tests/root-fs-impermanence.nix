{
  backend,
  disko,
  disko-zfs,
  impermanence,
  nixpkgs,
  pkgs,
  root,
}: let
  inherit (pkgs) lib;
  diskoLib = import (disko + "/lib") {
    inherit lib;
    makeTest = import (nixpkgs + "/nixos/tests/make-test-python.nix");
    eval-config = import (nixpkgs + "/nixos/lib/eval-config.nix");
    qemu-common = import (nixpkgs + "/nixos/lib/qemu-common.nix");
  };
  rootFsConfig = {
    imports = [
      ../../documentation/options.nix
      disko.nixosModules.disko
      disko-zfs.nixosModules.default
      impermanence.nixosModules.impermanence
      (root + "/modules/root-fs")
    ];

    networking.hostId = lib.mkIf (backend == "zfs") "8425e349";
    rootFs = {
      enable = true;
      inherit backend;
      diskId = "/dev/vda";
      encrypted = false;
      impermanent = true;
      swapSize = "512M";
      persistDirectories = [
        "/var/lib/impermanence-test"
        "/var/lib/nixos"
      ];
    };
    system.stateVersion = "26.05";
  };
  evaluated = import (nixpkgs + "/nixos/lib/eval-config.nix") {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [rootFsConfig];
  };
in
  diskoLib.testLib.makeDiskoTest {
    inherit pkgs;
    name = "root-fs-${backend}-impermanence";
    disko-config = {
      inherit (evaluated.config) disko;
      inherit (evaluated.config) boot;
    };
    extraInstallerConfig = lib.mkIf (backend == "zfs") {
      networking.hostId = "8425e349";
    };
    extraSystemConfig = rootFsConfig;
    bootCommands = ''
      import shutil

      def enable_restart(machine):
          ovmf_variables = machine.state_dir / "OVMF_VARS.fd"
          shutil.copyfile("${pkgs.OVMF.variables}", ovmf_variables)
          machine.start_command._cmd = machine.start_command._cmd.replace(
              "readonly=on,file=${pkgs.OVMF.variables}",
              f"file={ovmf_variables}",
          )
    '';
    extraTestScript = ''
      machine.wait_for_unit("multi-user.target")
      machine.succeed("test $(stat -c %a /) = 755")
      machine.succeed("test $(stat -c %a /etc) = 755")
      machine.succeed("getent passwd root")
      machine.succeed("systemctl is-active dbus.service")
      machine.succeed("touch /ephemeral-marker")
      machine.succeed("mkdir -p /var/lib/impermanence-test")
      machine.succeed("touch /var/lib/impermanence-test/persistent-marker")
      machine.succeed("sync")

      machine.shutdown()
      enable_restart(machine)
      machine.start()
      machine.wait_for_unit("multi-user.target")
      machine.fail("test -e /ephemeral-marker")
      machine.succeed("test -e /var/lib/impermanence-test/persistent-marker")
      machine.succeed("test $(stat -c %a /) = 755")
      machine.succeed("test $(stat -c %a /etc) = 755")
      machine.succeed("test $(stat -c %a /nix) = 755")
      machine.succeed("test $(stat -c %a /persist) = 755")
      machine.succeed("getent passwd root")
      machine.succeed("systemctl is-active dbus.service")
    '';
  }
