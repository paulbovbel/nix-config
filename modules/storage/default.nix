{
  config,
  lib,
  ...
}: let
  cfg = config.storage;
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
            inherit (dataset) group mode owner path;
            mountpoint = dataset.path;
            options = renderAutoSnapshot dataset.autoSnapshot // dataset.options;
          };
        }
        // flattenDatasetTree datasetName dataset.children
    )
    tree;
  datasetAttrs = flattenDatasetTree "" allDatasets;
  renderDataset = dataset: {
    properties =
      {
        inherit (dataset) mountpoint;
      }
      // dataset.options;
  };
  datasetOwnershipRules = lib.mapAttrsToList (_: dataset: "d ${dataset.path} ${dataset.mode} ${dataset.owner} ${dataset.group} - -") datasetAttrs;
in {
  options.moduleDocumentation.storage = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "Storage";
      summary = "Nested shared ZFS datasets with generated mount paths and snapshot policy.";
    };
  };

  imports = [./options.nix];

  config = lib.mkIf cfg.enable {
    storage.datasets.backup.autoSnapshot = {
      enable = true;
      frequent = false;
      hourly = false;
      daily = true;
      weekly = true;
      monthly = false;
    };

    boot.zfs.extraPools = [cfg.pool];

    services.zfs.autoScrub = {
      enable = true;
      interval = "monthly";
      pools = [cfg.pool];
    };

    systemd.tmpfiles.rules = datasetOwnershipRules;

    disko.zfs.settings.datasets =
      {
        ${cfg.pool}.properties = {
          mountpoint = cfg.dataPath;
          atime = "off";
          canmount = "on";
          "com.sun:auto-snapshot" = "false";
          "com.sun:auto-snapshot:weekly" = "true,keep=12";
          compression = "off";
          snapdir = "hidden";
        };
      }
      // lib.mapAttrs' (name: dataset: lib.nameValuePair "${cfg.pool}/${name}" (renderDataset dataset)) datasetAttrs;
  };
}
