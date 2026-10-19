# Monitoring

## Services

- `grafanaCloud.enable` exports host metrics to Grafana Cloud through Alloy.
  Set `grafanaCloud.role` to `desktop`, `laptop`, or `server`. Enable
  `grafanaCloud.smartctl.enable` where physical disks are accessible.
- `cockpit.enable` exposes host administration on port 9090.
- `smokeping.enable` records network latency using Podman and shared storage.

Alloy uses the agenix-managed `grafana-cloud-env` secret containing
`GRAFANA_CLOUD_API_KEY` and persists `/var/lib/private/alloy`. Smokeping stores
its configuration and history in `storage.datasets.app.children.smokeping`.
Grafana tenant settings live in `hosts/site.nix`. Alloy excludes loopback and
container veth/Podman interfaces from network metrics; VPN interfaces are retained.

## Grafana dashboards

Dashboards in `grafana/` are deployed to <https://bovbel.grafana.net> and use the
`grafanacloud-prom` datasource and Monitoring folder (`f4fzcd`). Deployment
overwrites changes made in the UI.

Deployment uses the explicit `gcx.yaml` context in this directory, with the
Grafana server and Cloud stack ID pinned so a fresh runner does not depend on
local gcx configuration or successful stack-ID discovery. Authentication comes
from `GRAFANA_TOKEN` in the environment.

Give the service account Edit access to the Monitoring folder, export its token
as `GRAFANA_TOKEN`, then run:

```bash
just monitor check
just monitor apply
```

CI deploys after successful validation and host builds on `main`, using the
`GRAFANA_TOKEN` Actions secret. The dashboard token is separate from Alloy's
metrics-publishing token.

Fleet charts link to host details and preserve the time range. Reporting hosts
counts current telemetry; sleeping or disconnected hosts eventually disappear.
Missing health metrics show **No data**. Host-detail tables identify failed
systemd units and unhealthy disks.

`just check` lints dashboards and tests queries without Grafana credentials.
The `alloy-config` flake check validates every enabled host's generated Alloy
configuration without publishing metrics.

## Troubleshooting

- **Metrics:** check `alloy.service`, `/etc/alloy/config.alloy`, and
  `/run/agenix/grafana-cloud-env`. For SMART metrics, check
  `prometheus-smartctl-exporter.service`.
- **Cockpit:** check `cockpit.socket` and `cockpit.service`.
- **Smokeping:** check `smokeping.service`, `apps-network.service`, and
  `/storage/app/smokeping/{config,data}`.
