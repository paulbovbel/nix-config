{
  config,
  lib,
  ...
}: let
  cfg = config.grafanaCloud;
  smartctlPort = config.services.prometheus.exporters.smartctl.port;
  smartctlConfig = lib.optionalString cfg.smartctl.enable ''

    prometheus.scrape "smartctl" {
      targets = [{
        "__address__" = "127.0.0.1:${toString smartctlPort}",
        "instance"    = "${config.networking.hostName}",
      }]
      forward_to      = [prometheus.remote_write.grafanacloud.receiver]
      scrape_interval = "60s"
    }
  '';
in {
  options.grafanaCloud = {
    enable = lib.mkEnableOption "host monitoring through Grafana Cloud";

    role = lib.mkOption {
      type = lib.types.enum ["desktop" "laptop" "server"];
      default = "desktop";
      description = "Host role attached to metrics for dashboards and alert routing.";
    };

    prometheus = {
      url = lib.mkOption {
        type = lib.types.str;
        default = "https://prometheus-us-central1.grafana.net/api/prom/push";
        description = "Grafana Cloud Prometheus remote-write endpoint.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "711583";
        description = "Grafana Cloud Prometheus tenant ID.";
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
        enable_collectors        = ["processes", "systemd"]

        systemd {
          enable_restarts = true
        }
      }

      prometheus.scrape "host" {
        targets         = prometheus.exporter.unix.host.targets
        forward_to      = [prometheus.remote_write.grafanacloud.receiver]
        scrape_interval = "60s"
      }

      prometheus.remote_write "grafanacloud" {
        external_labels = {
          host = "${config.networking.hostName}",
          role = "${cfg.role}",
        }

        endpoint {
          url = "${cfg.prometheus.url}"

          basic_auth {
            username = "${cfg.prometheus.username}"
            password = sys.env("GRAFANA_CLOUD_API_KEY")
          }
        }
      }
      ${smartctlConfig}
    '';

    services.prometheus.exporters.smartctl = lib.mkIf cfg.smartctl.enable {
      enable = true;
      listenAddress = "127.0.0.1";
      openFirewall = false;
    };

    systemd.tmpfiles.rules = ["d /var/lib/private 0700 root root -"];
    rootFs.persistDirectories = ["/var/lib/private/alloy"];
  };
}
