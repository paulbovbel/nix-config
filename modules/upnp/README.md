# UPnP

The UPnP module maintains declarative router port mappings. Other service modules use it for selected game and media ports, and hosts can declare additional mappings directly.

## Requirements

The default-route gateway must provide UPnP Internet Gateway Device support and permit discovery from the host's LAN. The module derives the destination address from the interface carrying the default IPv4 route and opens local UDP port 1900 for discovery. The service receiving a forwarded port must separately listen on the configured local port and allow it through the host firewall.

## Configuration

Each named forward maps an external router port to a local host port for TCP or UDP:

```nix
upnp.forwards.example = {
  from = 2456;
  to = 2456;
  proto = "udp";
};
```

Mappings expose the receiving service beyond the local network. Declare only ports that need direct inbound access and keep authentication and application updates appropriate for public exposure.

## Refresh Behavior

`upnp-update.service` installs each mapping with a two-hour lease. `upnp-update.timer` refreshes mappings hourly and catches up after downtime through its persistent timer. The service also runs during normal multi-user startup when at least one forward is declared.

## Troubleshooting

Inspect `upnp-update.service`, `upnp-update.timer`, and `journalctl -u upnp-update.service` for the name and endpoint of any failed mapping. Verify that the default-route interface has a global IPv4 address, UDP 1900 is allowed locally, and `upnpc -l` discovers the expected gateway. If the mapping exists but traffic still fails, test the receiving service on `LAN_ADDRESS:<to>` and check its firewall rule before changing the external `<from>` port.
