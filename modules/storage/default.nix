{
  config,
  lib,
  ...
}: let
  cfg = config.storage;
  dataPath = "/storage";
  baseDatasets = {};
  allDatasets = lib.recursiveUpdate baseDatasets cfg.datasets;
  renderAutoSnapshot = autoSnapshot:
    lib.mapAttrs' (
      name: value:
        lib.nameValuePair
        (
          if name == "enable"
          then "com.sun:auto-snapshot"
          else "com.sun:auto-snapshot:${name}"
        )
        (
          if builtins.isBool value
          then lib.boolToString value
          else value
        )
    )
    (lib.filterAttrs (_: value: value != null) autoSnapshot);
  flattenDatasetTree = prefix: tree:
    lib.concatMapAttrs (
      name: dataset: let
        datasetName =
          if prefix == ""
          then name
          else "${prefix}/${name}";
      in
        {
          ${datasetName} = {
            mountpoint = dataset.path;
            options = renderAutoSnapshot dataset.autoSnapshot // dataset.options;
          };
        }
        // flattenDatasetTree datasetName dataset.children
    )
    tree;
  datasetAttrs = flattenDatasetTree "" allDatasets;
  renderDataset = dataset: {
    type = "zfs_fs";
    inherit (dataset) mountpoint options;
  };
in {
  imports = [./options.nix];

  config = lib.mkIf cfg.enable {
    boot.zfs.extraPools = ["storage"];

    disko.devices.zpool.storage = {
      type = "zpool";
      mountpoint = dataPath;
      rootFsOptions = {
        atime = "off";
        canmount = "on";
        "com.sun:auto-snapshot" = "false";
        "com.sun:auto-snapshot:weekly" = "true,keep=12";
        compression = "off";
      };
      datasets = lib.mapAttrs (_: renderDataset) datasetAttrs;
    };
  };
}
