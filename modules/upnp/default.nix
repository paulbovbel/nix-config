{
  config,
  lib,
  pkgs,
  ...
}: let
  forwardType = lib.types.submodule {
    options = {
      from = lib.mkOption {type = lib.types.port;};
      to = lib.mkOption {type = lib.types.port;};
      proto = lib.mkOption {type = lib.types.enum ["tcp" "udp"];};
    };
  };
  cfg = config.upnp;
  forwards = lib.attrValues cfg.forwards;
in {
  options.upnp.forwards = lib.mkOption {
    type = lib.types.attrsOf forwardType;
    default = {};
    description = "UPnP forwards.";
  };

  config = lib.mkIf (forwards != []) {
    environment.systemPackages = [pkgs.miniupnpc];

    systemd.services.upnp-update = {
      description = "UPNP port forward update";
      wants = ["network-online.target"];
      after = ["network-online.target"];
      path = [pkgs.miniupnpc];
      serviceConfig.Type = "oneshot";
      script =
        lib.concatMapStringsSep "\n" (forward: ''
          upnpc -r ${toString forward.from} ${forward.proto} || true
        '')
        forwards;
    };

    systemd.timers.upnp-update = {
      description = "UPNP port forward update";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
      };
    };
  };
}
