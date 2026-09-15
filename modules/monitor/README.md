# Monitoring

The monitoring module exports host metrics to Grafana Cloud through Alloy, provides Cockpit for host administration, and runs Smokeping for network latency history.

## Requirements

Grafana Cloud monitoring requires the agenix-managed `grafana-cloud-env` secret containing `GRAFANA_CLOUD_API_KEY`. Set the host role to `desktop`, `laptop`, or `server`; optionally enable SMART metrics on hosts where `smartctl` can inspect the disks. Smokeping requires the Podman server and shared storage. Cockpit's configured web origins depend on the host name and tailnet domain.

## Persistence

Alloy state is persisted at `/var/lib/private/alloy` through the root filesystem persistence abstraction. Smokeping state is stored in `storage.datasets.app.children.smokeping`. Cockpit primarily exposes host state and does not declare a separate application dataset.

## Troubleshooting

For Grafana Cloud, inspect `alloy.service`, `/etc/alloy/config.alloy`, `/run/agenix/grafana-cloud-env`, and persisted state at `/var/lib/private/alloy`. If SMART metrics are missing, check `prometheus-smartctl-exporter.service` and its loopback listener. Smokeping uses `smokeping.service`, `apps-network.service`, and `/storage/app/smokeping/{config,data}`; Cockpit uses `cockpit.socket` and `cockpit.service` on port 9090.
