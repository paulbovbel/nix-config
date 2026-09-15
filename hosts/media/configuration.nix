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
    ../site.nix
    ./hardware-configuration.nix
  ];

  boot = {
    binfmt.emulatedSystems = ["aarch64-linux"];
    initrd.systemd.enable = true;
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # use LTS for appliance
    kernelPackages = pkgs.linuxPackages;
  };

  netboot = {
    enable = true;
    installLegacyImage = true;
  };

  networking = {
    hostName = "media";
    hostId = "48ed2069";
    useDHCP = false;
    interfaces = {
      eno1.useDHCP = true;
      eno2.useDHCP = true;
    };
    dhcpcd.extraConfig = ''
      noarp
      noipv4ll
    '';
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

  autoUpgrade.enable = true;

  githubRunner = {
    enable = true;
    url = "https://github.com/paulbovbel/nix-config";
    extraLabels = ["nix-media"];
  };

  # upnp.forwards.ssh = {
  #   from = 22;
  #   to = 22;
  #   proto = "tcp";
  # };

  caddy = {
    enable = true;
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
        roles = ["admin" "share"];
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
      {
        email = "pbovbel@gmail.com";
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
  caddy.sites.media.redirect = "/cockpit/";
  smokeping.enable = true;
  grafanaCloud.role = "server";

  mediaServer = {
    downloads.enable = true;
    downloads.popularVideos.channels = [
      {
        channel = "@natgeokids";
        count = 25;
        maxLength = 60;
      }
      {
        channel = "@MarkRober";
        count = 25;
        maxLength = 60;
      }
      {
        channel = "@SciShowKids";
        count = 25;
        maxLength = 60;
      }
    ];
    library.enable = true;
  };

  gameServer = {
    # abiotic.enable = true;
    upnp.enable = true;

    minecraft = {
      enable = true;
      ops = ["agent_x3r"];
      users = ["agent_x3r" "arteed2" "babablinchiki" "Waddle_Dee_dee"];
    };

    valheim = {
      enable = true;
      worldName = "Jewels";
      admins.agentx3r = "76561198028043290";
      permittedUsers = {
        Jewels42 = "76561199813276072";
        mjp0000 = "76561198120904256";
        supernatur4L = "76561197977879286";
        waterfox = "76561198197967175";
      };
      modifiers = {
        deathPenalty = "casual";
        playerBasedRaids = true;
        resources = "most";
      };
    };
  };

  rootFs = {
    enable = true;
    backend = "zfs";
    impermanent = true;
    encrypted = false;
    swapSize = "32G";
  };

  system.stateVersion = "26.05";
}
