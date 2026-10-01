"""Wait for automatic provisioning, surfacing validation errors immediately."""

import time

from django.db import OperationalError, ProgrammingError

from authentik.blueprints.models import BlueprintInstance
from authentik.blueprints.v1.importer import Importer
from authentik.tasks.models import TaskLog

deadline = time.monotonic() + 480
while time.monotonic() < deadline:
    try:
        instance = BlueprintInstance.objects.filter(
            path="custom/nix-config.yaml"
        ).first()
    except (OperationalError, ProgrammingError):
        # The containers are running before the first database migration completes.
        time.sleep(2)
        continue
    if instance and instance.status == "successful":
        break
    if instance and instance.status == "error":
        errors = list(
            TaskLog.objects.filter(
                task__in=instance.tasks.all(), log_level="error"
            ).values("event", "attributes")
        )
        valid, logs = Importer.from_string(
            instance.retrieve(), instance.context
        ).validate()
        print("Original errors:", errors)
        print("Current validation:", valid, logs)
        raise AssertionError("Automatic blueprint provisioning failed")
    time.sleep(2)
else:
    raise AssertionError("Automatic blueprint provisioning timed out")
