"""Evaluate real dashboard queries against synthetic metrics using Prometheus."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest


GRAFANA = Path(__file__).resolve().parents[1] / "grafana"


class DashboardQueriesTest(unittest.TestCase):
    def test_health_counts(self):
        dashboards = {
            name: json.loads((GRAFANA / f"{name}.json").read_text())["spec"]
            for name in ("fleet-overview", "host-detail")
        }

        def query(dashboard, title):
            panel = next(
                panel
                for panel in dashboards[dashboard]["panels"]
                if panel["title"] == title
            )
            return (
                panel["targets"][0]["expr"]
                .replace("$role", "server")
                .replace("$host", "media")
            )

        def expectation(dashboard, title, value):
            return {
                "expr": query(dashboard, title),
                "eval_time": "0m",
                "exp_samples": []
                if value is None
                else [{"labels": "{}", "value": value}],
            }

        def series(metric, labels, value):
            return {
                "series": f'{metric}{{role="server",{labels}}}',
                "values": str(value),
            }

        inputs = [
            series("node_uname_info", 'host="media"', 1),
            series("node_uname_info", 'host="desktop"', 1),
        ]
        for host, failures in (("media", 2), ("desktop", 1)):
            for unit in range(3):
                # Duplicate scrape targets must not inflate unit or disk counts.
                for instance in ("a", "b"):
                    inputs.append(
                        series(
                            "node_systemd_unit_state",
                            f'host="{host}",name="unit{unit}",state="failed",'
                            f'instance="{instance}"',
                            int(unit < failures),
                        )
                    )
                    inputs.append(
                        series(
                            "smartctl_device_smart_status",
                            f'host="{host}",device="disk{unit}",instance="{instance}"',
                            int(unit != 0),
                        )
                    )

        cases = [
            {
                "name": "multiple failures and duplicate targets",
                "input_series": inputs,
                "promql_expr_test": [
                    expectation("fleet-overview", "Hosts Reporting", 2),
                    expectation("fleet-overview", "Failed Systemd Units", 3),
                    expectation("host-detail", "Failed Systemd Units", 2),
                    expectation("fleet-overview", "SMART Failures", 2),
                    expectation("host-detail", "SMART Failures", 1),
                ],
            },
            {
                "name": "healthy disks",
                "input_series": [
                    series(
                        "smartctl_device_smart_status", 'host="media",device="sda"', 1
                    )
                ],
                "promql_expr_test": [
                    expectation(name, "SMART Failures", 0) for name in dashboards
                ],
            },
            {
                "name": "missing telemetry is not healthy telemetry",
                "input_series": [],
                "promql_expr_test": [
                    expectation(name, title, None)
                    for name in dashboards
                    for title in ("SMART Failures", "Failed Systemd Units")
                ]
                + [expectation("fleet-overview", "Hosts Reporting", 0)],
            },
        ]
        with tempfile.TemporaryDirectory() as directory:
            fixture = Path(directory) / "queries.json"
            fixture.write_text(
                json.dumps({"evaluation_interval": "1m", "tests": cases})
            )
            result = subprocess.run(
                ["promtool", "test", "rules", str(fixture)],
                capture_output=True,
                text=True,
                check=False,
            )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
