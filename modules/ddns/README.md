# Dynamic DNS

The Dynamic DNS module updates configured Route53 A records with the host's public IPv4 address every 30 minutes. It also runs a DNS server on `tailscale0` that resolves those records to the host's Tailscale IPv4 address, allowing Tailscale split DNS to use the same names internally.

## Requirements

The agenix-managed `/run/agenix/aws-access-env` file must provide AWS credentials and `AWS_HOSTED_ZONE_ID`. Configure at least one fully qualified record in `ddns.records` and set `ddns.zone` to its DNS zone.

Configure the host's Tailscale IPv4 address as a restricted nameserver for the applicable domains in the Tailscale admin console. The DNS server accepts TCP and UDP queries only through `tailscale0`. Names in `ddns.records` resolve to the host's Tailscale address; all other queries are forwarded in order to the host's upstream servers from `/run/systemd/resolve/resolv.conf`.

## Minimal Configuration

```nix
ddns = {
  enable = true;
  zone = "example.com";
  records = ["home.example.com"];
};
```

Declare the `aws-access-env` agenix secret with credentials for the Route53 hosted zone. Enable Tailscale on the host and configure its restricted nameserver as described above.

## Troubleshooting

Inspect `ddns-update.service` and `.timer` for public-address, credential, or Route53 failures. For tailnet DNS failures, inspect `ddns-tailscale-dns.service`; it retries until `tailscale ip --4` returns an address.
