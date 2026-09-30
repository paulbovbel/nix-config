"""Initialize packaged blueprints without running an Authentik worker or server."""

from authentik.blueprints.models import BlueprintInstance
from authentik.blueprints.v1.importer import Importer
from authentik.blueprints.v1.tasks import blueprints_find

pending = []
for blueprint in blueprints_find():
    if not blueprint.path.startswith(("default/", "system/")):
        continue
    if (
        blueprint.meta
        and str(
            blueprint.meta.labels.get("blueprints.goauthentik.io/instantiate", "true")
        ).lower()
        == "false"
    ):
        continue
    instance, _ = BlueprintInstance.objects.get_or_create(
        path=blueprint.path,
        defaults={"name": blueprint.meta.name if blueprint.meta else blueprint.path},
    )
    pending.append(instance)

# Packaged blueprints may reference one another; retry while making progress.
while pending:
    remaining = []
    for instance in pending:
        if not Importer.from_string(instance.retrieve()).apply():
            remaining.append(instance)
    assert len(remaining) < len(pending), [item.path for item in remaining]
    pending = remaining
