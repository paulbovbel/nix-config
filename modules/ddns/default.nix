{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ddns;
in {
  options.moduleDocumentation.ddns = lib.mkOption {
    internal = true;
    readOnly = true;
    default = {
      title = "Dynamic DNS";
      summary = "Automatic public and tailnet DNS records.";
    };
  };

  imports = [./options.nix];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.records != [];
        message = "ddns.records must contain at least one record when ddns.enable is true.";
      }
    ];

    age.secrets.aws-access-env.file = ../../secrets/server/aws-access-env.age;

    systemd = {
      services = {
        ddns-update = {
          description = "Point configured Route53 A records at this host's public IP";
          wants = ["network-online.target"];
          after = ["network-online.target"];
          path = [pkgs.awscli2 pkgs.coreutils pkgs.curl];
          serviceConfig = {
            Type = "oneshot";
            EnvironmentFile = config.age.secrets.aws-access-env.path;
            RuntimeDirectory = "ddns-update";
          };
          script = ''
            set -euo pipefail
            runtime_dir="$RUNTIME_DIRECTORY"
            public_ip=$(curl --fail --silent --show-error --max-time 10 https://checkip.amazonaws.com/)
            public_ip="''${public_ip//$'\n'/}"

            if [[ ! "$public_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
              printf 'Failed to determine public IPv4 address: %s\n' "$public_ip" >&2
              exit 1
            fi

            for record in ${lib.escapeShellArgs cfg.records}; do
              cat >"$runtime_dir/record.json" <<EOF
              {
                "Changes": [
                  {
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                      "Name": "$record.",
                      "Type": "A",
                      "TTL": 300,
                      "ResourceRecords": [
                        { "Value": "$public_ip" }
                      ]
                    }
                  }
                ]
              }
            EOF
              aws route53 change-resource-record-sets --hosted-zone-id "$AWS_HOSTED_ZONE" --change-batch "file://$runtime_dir/record.json"
            done
          '';
        };

        ddns-tailscale-dns = {
          description = "Resolve configured DDNS records to this host's Tailscale IP";
          wantedBy = ["multi-user.target"];
          wants = ["network-online.target" "tailscaled.service"];
          after = ["network-online.target" "tailscaled.service"];
          serviceConfig = {
            Type = "simple";
            Restart = "on-failure";
            RestartSec = "5s";
            RuntimeDirectory = "ddns-tailscale-dns";
          };
          script = ''
            set -euo pipefail
            tailscale_ip="$(${lib.getExe pkgs.tailscale} ip --4)"

            if [[ ! "$tailscale_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
              printf 'Failed to determine Tailscale IPv4 address: %s\n' "$tailscale_ip" >&2
              exit 1
            fi

            : >"$RUNTIME_DIRECTORY/hosts"
            dnsmasq_args=(
              --keep-in-foreground
              --interface=tailscale0
              --bind-dynamic
              --resolv-file=/run/systemd/resolve/resolv.conf
              --strict-order
              --no-hosts
              "--addn-hosts=$RUNTIME_DIRECTORY/hosts"
            )
            for record in ${lib.escapeShellArgs cfg.records}; do
              printf '%s %s\n' "$tailscale_ip" "$record" >>"$RUNTIME_DIRECTORY/hosts"
              dnsmasq_args+=("--local=/$record/")
            done
            exec ${lib.getExe pkgs.dnsmasq} "''${dnsmasq_args[@]}"
          '';
        };
      };

      timers.ddns-update = {
        description = "Schedule Route53 updates for this host's public IP";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = "*:0/30";
          Persistent = true;
        };
      };
    };

    networking.firewall.interfaces.tailscale0 = {
      allowedTCPPorts = [53];
      allowedUDPPorts = [53];
    };
  };
}
