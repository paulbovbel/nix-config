{
  config,
  lib,
  pkgs,
  ...
}: {
  age.secrets.robot-demo-wifi-password = {
    file = ../../secrets/laptop/robot-demo-wifi-password.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  networking = {
    wireless.enable = lib.mkForce false;

    networkmanager.unmanaged = [
      "br-robot"
      "enp0s31f6"
      "wlp0s20f3"
    ];

    bridges.br-robot.interfaces = ["enp0s31f6"];
    interfaces.br-robot = {
      useDHCP = false;
      ipv4.addresses = [
        {
          address = "10.4.0.1";
          prefixLength = 24;
        }
      ];
    };

    nat = {
      enable = true;
      externalInterface = "enp7s0u1";
      internalInterfaces = ["br-robot"];
    };

    firewall.trustedInterfaces = ["br-robot"];
  };

  services.hostapd = {
    enable = true;
    radios.wlp0s20f3 = {
      band = "2g";
      channel = 6;
      countryCode = "CA";
      wifi5.enable = false;
      networks.wlp0s20f3 = {
        ssid = "locusbots";
        settings.bridge = "br-robot";
        authentication = {
          mode = "wpa2-sha1";
          wpaPasswordFile = config.age.secrets.robot-demo-wifi-password.path;
        };
      };
    };
  };

  security.sudo.extraRules = [
    {
      users = ["pbovbel"];
      commands = [
        {
          command = "ALL";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  systemd.services = {
    robot-demo-unblock-wifi = {
      description = "Unblock Wi-Fi for the robot demo access point";
      after = ["NetworkManager.service"];
      before = ["hostapd.service"];
      requiredBy = ["hostapd.service"];
      serviceConfig.Type = "oneshot";
      script = "${pkgs.util-linux}/bin/rfkill unblock wifi";
    };

    hostapd.after = ["network-setup.service"];
  };
}
