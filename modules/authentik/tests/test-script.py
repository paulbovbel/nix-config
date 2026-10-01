# ruff: noqa: F821
"""NixOS test-driver entry point; machine is supplied by runNixOSTest."""

machine.start()
machine.wait_for_unit("authentik-db.service", timeout=180)
machine.wait_for_unit("authentik-worker.service", timeout=600)
machine.wait_for_unit("authentik.service", timeout=600)
machine.succeed(
    "podman exec authentik-worker ak shell -c "
    "'exec(open(\"/tests/wait-blueprint.py\").read())'",
    timeout=600,
)
machine.succeed("systemctl stop authentik-worker.service")
machine.succeed(
    "podman exec authentik ak shell -c "
    "'exec(open(\"/tests/check-blueprint.py\").read())'",
    timeout=600,
)
machine.succeed("systemctl start authentik-worker.service")
machine.wait_for_unit("authentik-worker.service", timeout=180)

for container in ("authentik", "authentik-worker"):
    machine.succeed(
        f"podman exec {container} python -c 'import os; "
        'assert os.environ["AUTHENTIK_CONFIDENTIAL_CLIENT_SECRET"] == "test-existing-client-secret"; '
        'assert os.environ["TEST_ENV_REVISION"] == "initial"'
        "'"
    )
machine.succeed(
    "cp /var/lib/authentik/secrets/clients/fresh.env /tmp/original-client.env"
)
machine.succeed("test $(stat -c %a /var/lib/authentik/secrets/clients/fresh.env) = 600")

# Change only a transitive environment definition and activate a new generation.
machine.succeed(
    "/run/current-system/specialisation/changed/bin/switch-to-configuration test"
)
for container in ("authentik", "authentik-worker"):
    machine.wait_until_succeeds(
        f"podman exec {container} python -c 'import os; "
        'assert os.environ["TEST_ENV_REVISION"] == "updated"'
        "'",
        timeout=180,
    )
machine.succeed(
    "cmp /tmp/original-client.env /var/lib/authentik/secrets/clients/fresh.env"
)
machine.succeed("podman exec authentik-db psql -U authentik -d authentik -c 'SELECT 1'")
machine.succeed(
    "podman exec authentik-worker ak shell -c "
    "'exec(open(\"/tests/wait-blueprint.py\").read())'",
    timeout=180,
)
