# Grafana dashboards

Dashboards in this directory are managed resources for `https://bovbel.grafana.net`.
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
