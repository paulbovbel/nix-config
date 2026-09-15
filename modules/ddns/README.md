# Dynamic DNS

The Dynamic DNS module updates configured Route53 A records with the host's public IPv4 address every 30 minutes.

## Requirements

The agenix-managed `/run/agenix/aws-access-env` file must provide AWS credentials and `AWS_HOSTED_ZONE`. Configure at least one fully qualified record in `ddns.records` and set `ddns.zone` to its DNS zone.

## Troubleshooting

Inspect `ddns-update.service` and `ddns-update.timer`. Failures normally identify public-address lookup errors from `checkip.amazonaws.com`, unavailable credentials, an incorrect hosted zone, or a Route53 record update rejected by AWS.
