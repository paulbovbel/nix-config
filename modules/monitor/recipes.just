set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set positional-arguments
set working-directory := "../.."

# Apply Grafana dashboards.
apply:
    @: "${GRAFANA_TOKEN:?GRAFANA_TOKEN must be set}"
    gcx resources push --config modules/monitor/gcx.yaml --context monitoring --path modules/monitor/grafana --on-error abort

# Lint Grafana dashboards.
check:
    gcx dev lint run modules/monitor/grafana
