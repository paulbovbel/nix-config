{
  pkgs,
  nixpkgs,
  disko,
  disko-zfs,
}: let
  inherit (pkgs) lib;
  evaluate = extra:
    (nixpkgs.lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        disko.nixosModules.disko
        disko-zfs.nixosModules.default
        ../default.nix
        {
          networking.hostId = "12345678";
          boot.loader.grub.enable = false;
          fileSystems."/" = {
            device = "none";
            fsType = "tmpfs";
          };
          system.stateVersion = "26.05";
        }
        extra
      ];
    }).config;
  disabled = evaluate {};
  empty = evaluate {storage.enable = true;};
  configured = evaluate {
    storage = {
      enable = true;
      pool = "vault";
      defaultOwner = "operator";
      defaultGroup = "users";
      datasets.media = {
        owner = "root";
        options.compression = "zstd";
        autoSnapshot = {
          enable = true;
          hourly = false;
          weekly = "true,keep=12";
        };
        children = {
          books = {};
          private = {
            owner = "root";
            group = "root";
            mode = "0700";
          };
        };
      };
    };
  };
  inactive = evaluate {
    storage.datasets.unused = {};
  };
  noRuntimeEffects = cfg:
    cfg.boot.zfs.extraPools
    == []
    && cfg.disko.zfs.settings.datasets == {}
    && !cfg.services.zfs.autoScrub.enable
    && !(builtins.any (lib.hasPrefix "d /storage/") cfg.systemd.tmpfiles.rules);
  tests = {
    disabledHasNoPolicy = disabled.storage.datasets == {} && noRuntimeEffects disabled;
    disabledDeclarationsStayInactive = noRuntimeEffects inactive;
    enabledHasNoWorkloadDatasets =
      empty.storage.datasets
      == {}
      && lib.attrNames empty.disko.zfs.settings.datasets == ["storage"];
    independentOwnershipDefaults =
      inactive.storage.datasets.unused.owner
      == "root"
      && inactive.storage.datasets.unused.group == "root";
    generatedPaths = configured.storage.datasets.media.children.books.path == "/vault/media/books";
    poolSelection =
      configured.boot.zfs.extraPools
      == ["vault"]
      && configured.services.zfs.autoScrub.pools == ["vault"];
    flattenedDatasets = lib.attrNames configured.disko.zfs.settings.datasets == ["vault" "vault/media" "vault/media/books" "vault/media/private"];
    datasetProperties =
      configured.disko.zfs.settings.datasets."vault/media".properties
      == {
        mountpoint = "/vault/media";
        compression = "zstd";
        "com.sun:auto-snapshot" = "true";
        "com.sun:auto-snapshot:hourly" = "false";
        "com.sun:auto-snapshot:weekly" = "true,keep=12";
      };
    defaultOwnership = builtins.elem "d /vault/media/books 0755 operator users - -" configured.systemd.tmpfiles.rules;
    explicitOwnership = builtins.elem "d /vault/media/private 0700 root root - -" configured.systemd.tmpfiles.rules;
    configuredEvaluation = (builtins.tryEval configured.system.build.toplevel.drvPath).success;
  };
  failed = lib.attrNames (lib.filterAttrs (_: passed: !passed) tests);
in
  assert lib.assertMsg (failed == []) "Storage contract failures: ${lib.concatStringsSep ", " failed}";
    pkgs.runCommand "storage-contracts" {} "touch $out"
