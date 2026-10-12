{
  config,
  lib,
  ...
}: let
  cfg = config.grafanaCloud;
  smartctlPort = config.services.prometheus.exporters.smartctl.port;
in {
  options.grafanaCloud = {
    enable = lib.mkEnableOption "host monitoring through Grafana Cloud";

    role = lib.mkOption {
      type = lib.types.enum ["desktop" "laptop" "server"];
      default = "desktop";
      description = "Host role attached to every exported metric for dashboard filtering and alert routing.";
    };

    prometheus = {
      url = lib.mkOption {
        type = lib.types.str;
        description = "HTTPS endpoint to which Alloy remotely writes Prometheus metrics.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        description = "Grafana Cloud Prometheus tenant ID used for remote-write basic authentication.";
      };
    };

    smartctl.enable = lib.mkEnableOption "SMART metrics collection";
  };

  config = lib.mkIf cfg.enable {
    age.secrets.grafana-cloud-env = {
      file = ../../secrets/common/grafana-cloud-env.age;
      owner = "root";
      group = "root";
      mode = "0400";
    };

    services.alloy = {
      enable = true;
      environmentFile = config.age.secrets.grafana-cloud-env.path;
      extraFlags = ["--disable-reporting"];
    };

    environment.etc."alloy/config.alloy".text = ''
      prometheus.exporter.unix "host" {
        include_exporter_metrics = true
        enable_collectors        = ["systemd"]

        netdev {
          device_exclude = "^(lo|veth.*|podman.*)$"
        }

        netclass {
          ignored_devices = "^(lo|veth.*|podman.*)$"
        }
      }

      prometheus.scrape "host" {
        targets         = prometheus.exporter.unix.host.targets
        forward_to      = [prometheus.remote_write.grafanacloud.receiver]
        scrape_interval = "60s"
      }

      prometheus.remote_write "grafanacloud" {
        external_labels = {
          host = ${builtins.toJSON config.networking.hostName},
          role = ${builtins.toJSON cfg.role},
        }

        endpoint {
          url = ${builtins.toJSON cfg.prometheus.url}

          basic_auth {
            username = ${builtins.toJSON cfg.prometheus.username}
            password = sys.env("GRAFANA_CLOUD_API_KEY")
          }
        }
      }
      ${lib.optionalString cfg.smartctl.enable ''
        prometheus.scrape "smartctl" {
          targets = [{
            "__address__" = ${builtins.toJSON "127.0.0.1:${toString smartctlPort}"},
            "instance"    = ${builtins.toJSON config.networking.hostName},
          }]
          forward_to      = [prometheus.remote_write.grafanacloud.receiver]
          scrape_interval = "60s"
        }
      ''}
    '';

    services.prometheus.exporters.smartctl = lib.mkIf cfg.smartctl.enable {
      enable = true;
      listenAddress = "127.0.0.1";
      openFirewall = false;
    };
  };
}
