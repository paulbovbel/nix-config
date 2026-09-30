# Monitoring

The monitoring module exports host metrics to Grafana Cloud through Alloy, provides Cockpit for host administration, and runs Smokeping for network latency history.

## Grafana Cloud

`grafanaCloud.enable` runs Alloy and exports host metrics through Prometheus remote write. Set `grafanaCloud.role` to `desktop`, `laptop`, or `server` to label metrics. The username is the Grafana Cloud tenant ID; the API key comes from `grafana-cloud-env`.

### SMART Metrics

Enable `grafanaCloud.smartctl.enable` only where it can inspect physical disks.

## Cockpit

`cockpit.enable` exposes Cockpit on port 9090 with origins derived from the host and tailnet domains.

## Smokeping

`smokeping.enable` runs Smokeping as a container with persistent configuration and latency history in shared storage.

## Requirements

Grafana Cloud needs the agenix-managed `grafana-cloud-env` secret containing `GRAFANA_CLOUD_API_KEY`. Smokeping needs the Podman server and shared storage.

## Persistence

Alloy persists `/var/lib/private/alloy`; Smokeping uses `storage.datasets.app.children.smokeping`.

## Troubleshooting

For Grafana Cloud, inspect `alloy.service`, `/etc/alloy/config.alloy`, `/run/agenix/grafana-cloud-env`, and persisted state at `/var/lib/private/alloy`. If SMART metrics are missing, check `prometheus-smartctl-exporter.service` and its loopback listener. Smokeping uses `smokeping.service`, `apps-network.service`, and `/storage/app/smokeping/{config,data}`; Cockpit uses `cockpit.socket` and `cockpit.service` on port 9090.

## Grafana dashboards

Dashboards under `grafana/` are managed resources for `https://bovbel.grafana.net`.
Changes made in the Grafana UI will be overwritten by the next deployment.

Create a Grafana service account with the Editor role, then store its token in
`secrets/management/grafana-cloud-env.age`:

```text
GRAFANA_TOKEN=glsa_...
```

Validate and preview changes before applying them:

```bash
just dashboards-check
just dashboards-dry-run
just dashboards-apply
```

The management secret is encrypted only to the `pbovbel` recipient and is not
deployed to monitored hosts. The metrics publishing token remains separately
managed in `secrets/common/grafana-cloud-env.age`.
