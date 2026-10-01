{
  nixpkgs,
  nixos-apple-silicon,
  hosts,
  mkHost,
}: {
  firmwareDirectory ? null,
  hostName,
  keyPayload,
  stateBackup ? null,
  unlockPayload,
}: let
  inherit (nixpkgs) lib;
  host = hosts.${hostName} or (throw "Unknown installer host: ${hostName}");
  inherit (host) system;
  isAppleSilicon = host.installer == "apple-silicon";
  targetSystem = mkHost hostName host (lib.optional (firmwareDirectory != null) {
    hardware.asahi.peripheralFirmwareDirectory = lib.mkForce firmwareDirectory;
  });
in
  assert lib.assertMsg (builtins.elem host.installer ["generic" "apple-silicon"]) "Unknown installer kind for ${hostName}: ${host.installer}";
  assert lib.assertMsg (firmwareDirectory == null || isAppleSilicon) "Firmware payloads require an apple-silicon installer";
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {
        expectedRecipient = host.ageRecipient;
        inherit isAppleSilicon keyPayload stateBackup targetSystem unlockPayload;
      };
      modules =
        (
          if isAppleSilicon
          then [nixos-apple-silicon.nixosModules.apple-silicon-installer]
          else [(nixpkgs + "/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix")]
        )
        ++ [./default.nix {nixpkgs.hostPlatform.system = system;}]
        ++ lib.optional isAppleSilicon {
          hardware.asahi.pkgsSystem = system;
          hardware.apple.touchBar = {
            enable = true;
            package = targetSystem.config.hardware.apple.touchBar.package;
          };
        }
        ++ lib.optional (isAppleSilicon && firmwareDirectory != null) {
          hardware.asahi.peripheralFirmwareDirectory = lib.mkForce firmwareDirectory;
        };
    }
