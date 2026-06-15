{pkgs, ...}: {
  imports = [
    ./hardware-configuration.nix
  ];

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # use LTS for appliance
    kernelPackages = pkgs.linuxPackages;
  };

  networking = {
    hostName = "media";
    hostId = "48ed2069";
  };

  ddns = {
    enable = true;
    zone = "bovbel.com";
    record = "media.bovbel.com";
  };

  upnp.forwards.ssh = {
    from = 22;
    to = 22;
    proto = "tcp";
  };

  caddy = {
    enable = true;
    components.share.enable = true;

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

  cockpit.enable = true;
  smokeping.enable = true;

  syncthing = {
    # enable = true;
    caddy.enable = true;
  };

  mediaServer = {
    enable = true;
    components = {
      downloads.enable = true;
      library.enable = true;
    };
    upnp.enable = true;
  };

  gameServer = {
    enable = true;
    components = {
      abiotic.enable = true;
      minecraft.enable = true;
    };
    upnp.enable = true;

    minecraft = {
      ops = ["agent_x3r"];
      users = ["agent_x3r" "arteed2" "babablinchiki" "Waddle_Dee_dee"];
    };
  };

  impermanenceRoot = {
    enable = true;
    swapSize = "32G";
  };

  system.stateVersion = "26.05";
}
