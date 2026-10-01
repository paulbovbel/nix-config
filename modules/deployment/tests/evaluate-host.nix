{
  host,
  metadata,
}: let
  # CI can evaluate the Apple host without accessing its non-redistributable
  # ESP firmware. This override is never used for deployment or host builds.
  evaluation =
    if metadata.installer == "apple-silicon"
    then
      host.extendModules {
        modules = [
          ({lib, ...}: {
            hardware.asahi.peripheralFirmwareDirectory = lib.mkForce null;
            hardware.asahi.extractPeripheralFirmware = lib.mkForce false;
          })
        ];
      }
    else host;
in
  evaluation.config.system.build.toplevel.drvPath
