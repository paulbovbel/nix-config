# Dynamic DNS

The Dynamic DNS module updates configured Route53 A records with the host's public IPv4 address every 30 minutes. It also runs a DNS server on `tailscale0` that resolves those records to the host's Tailscale IPv4 address, allowing Tailscale split DNS to use the same names internally.

## Requirements

The agenix-managed `/run/agenix/aws-access-env` file must provide AWS credentials and `AWS_HOSTED_ZONE`. Configure at least one fully qualified record in `ddns.records` and set `ddns.zone` to its DNS zone.

Configure the host's Tailscale IPv4 address as a restricted nameserver for the applicable domains in the Tailscale admin console. The DNS server accepts TCP and UDP queries only through `tailscale0`. Names in `ddns.records` resolve to the host's Tailscale address; all other queries are forwarded in order to the host's upstream servers from `/run/systemd/resolve/resolv.conf`.

## Troubleshooting

Inspect `ddns-update.service` and `ddns-update.timer`. Failures normally identify public-address lookup errors from `checkip.amazonaws.com`, unavailable credentials, an incorrect hosted zone, or a Route53 record update rejected by AWS.

Inspect `ddns-tailscale-dns.service` for tailnet DNS failures. It retries until `tailscale ip --4` returns the host's address.
