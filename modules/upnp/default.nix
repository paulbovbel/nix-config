{
  config,
  lanAddressCommand,
  lib,
  pkgs,
  ...
}: let
  forwardType = lib.types.submodule {
    options = {
      from = lib.mkOption {
        type = lib.types.port;
        description = "External router port to forward.";
      };
      to = lib.mkOption {
        type = lib.types.port;
        description = "Local host port receiving forwarded traffic.";
      };
      proto = lib.mkOption {
        type = lib.types.enum ["tcp" "udp"];
        description = "Transport protocol to forward.";
      };
    };
  };
  cfg = config.upnp;
  forwards = lib.mapAttrsToList (name: forward: forward // {inherit name;}) cfg.forwards;
in {
  options.moduleDocumentation.upnp = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "UPnP";
      summary = "Periodic router port-forward declarations.";
    };
  };

  options.upnp.forwards = lib.mkOption {
    type = lib.types.attrsOf forwardType;
    default = {};
    description = "UPnP forwards.";
  };

  config = lib.mkIf (forwards != []) {
    environment.systemPackages = [pkgs.miniupnpc];

    systemd.services.upnp-update = {
      description = "Refresh configured UPnP port forwards to this host";
      wantedBy = ["multi-user.target"];
      wants = ["network-online.target"];
      after = ["network-online.target"];
      path = [pkgs.gawk pkgs.iproute2 pkgs.miniupnpc];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
      };
      script =
        ''
          LAN_ADDRESS="$(${lanAddressCommand})"

          if [ -z "$LAN_ADDRESS" ]; then
            echo "Could not determine LAN_ADDRESS" >&2
            exit 1
          fi

          failures=0
        ''
        + lib.concatMapStringsSep "\n" (forward: ''
          if ! upnpc -z 1900 -a "$LAN_ADDRESS" ${toString forward.to} ${toString forward.from} ${forward.proto} 7200; then
            echo "Failed to update UPnP forward '${forward.name}': ${toString forward.from}/${forward.proto} -> $LAN_ADDRESS:${toString forward.to}" >&2
            failures=$((failures + 1))
          fi
        '')
        forwards
        + ''

          if [ "$failures" -gt 0 ]; then
            echo "Failed to update $failures UPnP forward(s)" >&2
            exit 1
          fi
        '';
    };

    networking.firewall.allowedUDPPorts = [1900];

    systemd.timers.upnp-update = {
      description = "Schedule refreshes for configured UPnP port forwards";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };
  };
}
