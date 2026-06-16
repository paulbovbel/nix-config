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
    age.secrets.aws-access-env.file = ../../secrets/server/aws-access-env.age;

    systemd.services.ddns-update = {
      description = "Update Route53 records";
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

        cat >"$runtime_dir/record.json" <<EOF
        {
          "Changes": [
            {
              "Action": "UPSERT",
              "ResourceRecordSet": {
                "Name": "${cfg.record}.",
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
      '';
    };

    systemd.timers.ddns-update = {
      description = "Update Route53 records";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*:0/30";
        Persistent = true;
      };
    };
  };
}
