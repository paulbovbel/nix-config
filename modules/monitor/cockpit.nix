{
  config,
  lib,
  pkgs,
  pcp,
  ...
}: let
  cockpitPython = pkgs.cockpit.passthru.python3Packages.python;
  pcpPackage = import "${pcp}/build/nix/package.nix" {
    pkgs =
      pkgs
      // {
        python3 = cockpitPython;
      };
    src = pcp;
  };
  pcpPythonPath = "${pcpPackage}/lib/${cockpitPython.libPrefix}/site-packages";
  pcpLibraryPath = "${pcpPackage}/lib";
  pcpConf = pkgs.writeText "pcp.conf" (builtins.replaceStrings [
      "PCP_VAR_DIR=${pcpPackage}/var/lib/pcp"
      "PCP_LOG_DIR=${pcpPackage}/var/log/pcp"
      "PCP_ARCHIVE_DIR=${pcpPackage}/var/log/pcp/pmlogger"
      "PCP_TMP_DIR=${pcpPackage}/var/lib/pcp/tmp"
    ] [
      "PCP_VAR_DIR=/var/lib/pcp"
      "PCP_LOG_DIR=/var/log/pcp"
      "PCP_ARCHIVE_DIR=/var/log/pcp/pmlogger"
      "PCP_TMP_DIR=/var/lib/pcp/tmp"
    ]
    (builtins.readFile "${pcpPackage}/share/pcp/etc/pcp.conf"));
  pcpEnvironment = lib.mapAttrs (_: lib.mkForce) {
    PCP_CONF = pcpConf;
    PCP_DIR = "${pcpPackage}/share/pcp";
    PCP_VAR_DIR = "/var/lib/pcp";
    PCP_LOG_DIR = "/var/log/pcp";
    PCP_ARCHIVE_DIR = "/var/log/pcp/pmlogger";
    PCP_TMP_DIR = "/var/lib/pcp/tmp";
    PCP_RUN_DIR = "/run/pcp";
    PCP_PMCDCONF_PATH = "/etc/pcp/pmcd/pmcd.conf";
    PWDCMND = "pwd";
  };
  switchTmpfilesUnit = "systemd-tmpfiles-resetup.service";
  cockpitPackage = pkgs.cockpit.overrideAttrs (old: {
    postFixup =
      (old.postFixup or "")
      + ''
        wrapProgram $out/bin/cockpit-bridge \
          --set PCP_CONF ${pcpConf} \
          --set PCP_DIR ${pcpPackage}/share/pcp \
          --prefix PYTHONPATH : ${pcpPythonPath} \
          --prefix LD_LIBRARY_PATH : ${pcpLibraryPath}
      '';
  });
in {
  options.cockpit.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Cockpit web UI.";
  };

  config = lib.mkIf config.cockpit.enable {
    services.cockpit = {
      enable = true;
      package = cockpitPackage;
      openFirewall = false;
      allowed-origins = [
        "https://${config.networking.hostName}.${config.networking.domain}"
        "wss://${config.networking.hostName}.${config.networking.domain}"
        "https://${config.networking.hostName}.${config.tailscale.domain}"
        "wss://${config.networking.hostName}.${config.tailscale.domain}"
      ];
      plugins = [pkgs.cockpit-files pkgs.cockpit-podman];
      settings.WebService = {
        AllowUnencrypted = true;
        LoginTo = false;
        ProtocolHeader = "X-Forwarded-Proto";
        UrlRoot = "/cockpit";
      };
    };

    services.pcp = {
      enable = true;
      package = pcpPackage;

      # standalone = pmcd + pmlogger + pmie + pmproxy
      # This is what you want for Cockpit history.
      preset = "standalone";

      openFirewall = false; # only needed for remote PCP clients
    };

    systemd.services =
      {
        cockpit = {
          after = [switchTmpfilesUnit];
          environment = {
            inherit (pcpEnvironment) PCP_CONF PCP_DIR;
            PYTHONPATH = pcpPythonPath;
            LD_LIBRARY_PATH = pcpLibraryPath;
          };
          serviceConfig.ExecStart = lib.mkForce [
            ""
            "${config.services.cockpit.package}/libexec/cockpit-tls --no-tls"
          ];
        };

        pmlogger-daily.environment =
          pcpEnvironment
          // {
            PCP_REMOTE_ARCHIVE_DIR = "/var/log/pcp/pmproxy";
          };

        pmie-daily.environment = pcpEnvironment;
      }
      // lib.genAttrs ["pmcd" "pmlogger" "pmie" "pmproxy"] (name:
        {
          after = [switchTmpfilesUnit];
          environment = pcpEnvironment;
        }
        // lib.optionalAttrs (name == "pmcd") {
          serviceConfig = {
            Group = "pcp";
            RuntimeDirectoryMode = "0775";
          };
        });

    environment.variables = pcpEnvironment;

    caddy.sites.media.endpoints.cockpit = {
      type = "proxy";
      auth = "oauth";
      path = "/cockpit";
      host = "host.containers.internal";
      port = 9090;
      role = "admin";
      spoofBasic = true;
    };

    networking.firewall.interfaces.${config.podmanServer.networkInterface}.allowedTCPPorts = [config.services.cockpit.port];
  };
}
