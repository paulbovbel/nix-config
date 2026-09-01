{
  locus-vpn-client,
  pkgs,
  ...
}: {
  imports = [
    ../graphical/system.nix
  ];

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  services.strongswan = {
    enable = true;
    secrets = ["ipsec.d/ipsec.nm-l2tp.secrets"];
  };

  networking.networkmanager.plugins = [
    pkgs.networkmanager-l2tp
  ];

  systemd.tmpfiles.rules = [
    "d /etc/ipsec.d 0755 root root -"
  ];

  rootFs.persistDirectories = [
    "/etc/ipsec.d"
  ];

  environment = {
    etc = {
      "strongswan.conf".text = "";
    };

    systemPackages = [
      pkgs.distrobox
      pkgs.ike-scan
      locus-vpn-client.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
  };

  services.flatpak.packages = [
    "com.slack.Slack"
    "us.zoom.Zoom"
  ];
}
