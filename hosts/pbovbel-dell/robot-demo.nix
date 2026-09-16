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
      channel = 11;
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

  powerManagement.resumeCommands = ''
    ${config.systemd.package}/bin/systemctl stop hostapd.service
    ${pkgs.kmod}/bin/modprobe -r iwlmvm || true
    sleep 2
    ${pkgs.kmod}/bin/modprobe iwlwifi
    sleep 3
    ${pkgs.util-linux}/bin/rfkill unblock wifi
    ${config.systemd.package}/bin/systemctl reset-failed hostapd.service robot-demo-unblock-wifi.service
    ${config.systemd.package}/bin/systemctl start hostapd.service
  '';

  systemd.services = {
    robot-demo-resolver = {
      description = "Configure split DNS for the robot demo network";
      after = [
        "network-setup.service"
        "systemd-resolved.service"
      ];
      requires = ["systemd-resolved.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${config.systemd.package}/bin/resolvectl dns br-robot 10.4.0.5
        ${config.systemd.package}/bin/resolvectl domain br-robot '~locus' 'locus-canada.locus'
        ${config.systemd.package}/bin/resolvectl default-route br-robot false
      '';
      postStop = ''
        ${config.systemd.package}/bin/resolvectl revert br-robot || true
      '';
    };

    robot-demo-disable-ethernet-eee = {
      description = "Stabilize the robot demo Ethernet link";
      after = ["sys-subsystem-net-devices-enp0s31f6.device"];
      bindsTo = ["sys-subsystem-net-devices-enp0s31f6.device"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        ${pkgs.ethtool}/bin/ethtool --change enp0s31f6 advertise 0x008 autoneg on
        ${pkgs.ethtool}/bin/ethtool --set-eee enp0s31f6 eee off
      '';
    };

    robot-demo-unblock-wifi = {
      description = "Unblock Wi-Fi for the robot demo access point";
      after = ["NetworkManager.service"];
      before = ["hostapd.service"];
      requiredBy = ["hostapd.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = "${pkgs.util-linux}/bin/rfkill unblock wifi";
    };

    hostapd.after = ["network-setup.service"];
  };
}
