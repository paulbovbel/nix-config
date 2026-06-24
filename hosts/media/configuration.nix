{
  config,
  lib,
  pkgs,
  ...
}: let
  backupPath = config.storage.datasets.backup.path;
  appBackupPaths =
    lib.mapAttrs (name: dataset: {
      source = dataset.path;
      destination = "app/${name}";
    })
    config.storage.datasets.app.children;
  fullBackupPaths =
    {
      backup = {
        source = backupPath;
        destination = "backup";
      };
      audiobooks = {
        source = config.storage.datasets.media.children.audiobooks.path;
        destination = "media/audiobooks";
      };
      books = {
        source = config.storage.datasets.media.children.books.path;
        destination = "media/books";
      };
      comics = {
        source = config.storage.datasets.media.children.comics.path;
        destination = "media/comics";
      };
    }
    // appBackupPaths;
  limitedBackupPaths =
    {
      backupDocuments = {
        source = "${backupPath}/documents";
        destination = "backup/documents";
      };
      backupPhotos = {
        source = "${backupPath}/photos";
        destination = "backup/photos";
      };
    }
    // appBackupPaths;
in {
  imports = [
    ./hardware-configuration.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # use LTS for appliance
    kernelPackages = pkgs.linuxPackages;

    # The ASPEED BMC VGA adapter reports a corrupt EDID and floods the journal.
    blacklistedKernelModules = ["ast"];
  };

  netboot.installLegacyImage = true;

  networking = {
    hostName = "media";
    hostId = "48ed2069";
  };

  ddns = {
    enable = true;
    zone = "bovbel.com";
    records = [
      "media.bovbel.com"
      "nix-cache.bovbel.com"
    ];
  };

  atticCache = {
    enable = true;
  };

  # upnp.forwards.ssh = {
  #   from = 22;
  #   to = 22;
  #   proto = "tcp";
  # };

  caddy = {
    enable = true;
    primarySubdomain = "media";
    share.enable = true;

    users = [
      {
        email = "paul@bovbel.com";
        roles = ["admin" "share"];
      }
      {
        email = "rebecca@bovbel.com";
        roles = ["admin" "share"];
      }
      {
        email = "andrew@bovbel.com";
        roles = ["admin" "share"];
      }
      {
        email = "irina@bovbel.com";
        roles = ["share"];
      }
      {
        email = "dmitri@bovbel.com";
        roles = ["share"];
      }
      {
        email = "arthur@bovbel.com";
        roles = ["share"];
      }
      {
        email = "igorlitvinov@gmail.com";
        roles = ["share"];
      }
      {
        email = "eugene.tkach@gmail.com";
        roles = ["share"];
      }
    ];
  };

  storage.enable = true;

  backup = {
    targets = {
      "de4856@de4856.rsync.net".paths = limitedBackupPaths;
      "pbovbel@offsite".paths = fullBackupPaths;
    };
    remoteRoot = "media";
    identityFile = config.age.secrets.pbovbel-ssh-private-key.path;
  };

  environment.systemPackages = [pkgs.intel-gpu-tools];

  cockpit.enable = true;
  caddy.redirect = "/cockpit/";
  smokeping.enable = true;

  # syncthing = {
  #   enable = true;
  # };

  mediaServer = {
    downloads.enable = true;
    library.enable = true;
  };

  # gameServer = {
  #   abiotic.enable = true;
  #   minecraft.enable = true;
  #   upnp.enable = true;

  #   minecraft = {
  #     ops = ["agent_x3r"];
  #     users = ["agent_x3r" "arteed2" "babablinchiki" "Waddle_Dee_dee"];
  #   };
  # };

  impermanenceRoot = {
    enable = true;
    encrypted = false;
    swapSize = "32G";
  };

  system.stateVersion = "26.05";
}
