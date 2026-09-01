{
  nixpkgs,
  system,
}: hostName: hostConfig:
nixpkgs.lib.nixosSystem {
  inherit system;
  modules = [
    "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
    ({
      lib,
      pkgs,
      ...
    }: let
      installSystem = pkgs.writeShellApplication {
        name = "install-system";
        runtimeEnv = {
          HOST_NAME = hostName;
          TARGET_DISK = hostConfig.config.rootZfs.diskId;
          DISKO_SCRIPT = hostConfig.config.system.build.diskoScript;
          NIXOS_INSTALL = "${hostConfig.config.system.build.nixos-install}/bin/nixos-install";
          TARGET_SYSTEM = hostConfig.config.system.build.toplevel;
        };
        text = builtins.readFile ./install-system.sh;
      };
    in {
      boot.supportedFilesystems = ["zfs"];
      boot.zfs.forceImportRoot = false;
      environment.systemPackages = [installSystem];
      image.baseName = lib.mkForce "nixos-${hostName}-installer";

      systemd.services.install-system = {
        description = "Install ${hostName}";
        wantedBy = ["multi-user.target"];
        after = ["systemd-udev-settle.service"];
        wants = ["systemd-udev-settle.service"];
        conflicts = ["getty@tty1.service"];
        unitConfig.ConditionPathExists = "/dev/disk/by-label/NIXOS_KEYS";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = lib.getExe installSystem;
          StandardInput = "tty-force";
          StandardOutput = "tty";
          StandardError = "tty";
          TTYPath = "/dev/tty1";
          TTYReset = true;
          TTYVHangup = true;
        };
      };
    })
  ];
}
