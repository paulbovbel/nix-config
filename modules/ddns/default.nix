{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.ddns;
in {
  imports = [./options.nix];

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.records != [];
        message = "ddns.records must contain at least one record when ddns.enable is true.";
      }
    ];

    age.secrets.aws-access-env.file = ../../secrets/server/aws-access-env.age;

    systemd.services.ddns-update = {
      description = "Point configured Route53 A records at this host's Tailscale IP";
      wants = ["network-online.target" "tailscaled.service"];
      after = ["network-online.target" "tailscaled.service"];
      path = [pkgs.awscli2 pkgs.coreutils pkgs.tailscale];
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = config.age.secrets.aws-access-env.path;
        RuntimeDirectory = "ddns-update";
      };
      script = ''
        set -euo pipefail
        runtime_dir="$RUNTIME_DIRECTORY"
        tailscale_ip=$(tailscale ip -4 | head -n1)

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
                    { "Value": "$tailscale_ip" }
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

    systemd.timers.ddns-update = {
      description = "Schedule Route53 updates for this host's Tailscale IP";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*:0/30";
        Persistent = true;
      };
    };
  };
}
