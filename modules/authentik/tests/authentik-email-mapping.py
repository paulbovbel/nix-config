"""Apply and verify the generated blueprint after packaged blueprints are loaded."""

from pathlib import Path

from django.test import RequestFactory

from authentik.blueprints.v1.importer import Importer
from authentik.core.models import Application, User
from authentik.providers.oauth2.models import OAuth2Provider, ScopeMapping
from authentik.providers.proxy.models import ProxyProvider

blueprint = Path("/blueprints/custom/nix-config.yaml").read_text()
default = ScopeMapping.objects.get(
    managed="goauthentik.io/providers/oauth2/scope-email"
)
original_expression = default.expression
assert Importer.from_string(blueprint).apply(), "Generated blueprint failed"
user = User.objects.get(username="paul@bovbel.com")
request = RequestFactory().get("/application/o/userinfo/")
request.user = user


def check_mappings():
    custom = ScopeMapping.objects.get(name="nix-config email")
    for client_id in ("audiobookshelf", "grimmory"):
        provider = OAuth2Provider.objects.get(client_id=client_id)
        application = Application.objects.get(slug=client_id)
        expected_url = f"https://media.bovbel.com/{client_id}/"
        assert application.meta_launch_url == expected_url
        assert application.get_launch_url() == expected_url
        assert provider.grant_types == ["authorization_code", "refresh_token"], (
            client_id,
            provider.grant_types,
        )
        mappings = ScopeMapping.objects.filter(
            pk__in=provider.property_mappings.values("pk"), scope_name="email"
        )
        assert list(mappings) == [custom], (client_id, list(mappings))
        assert mappings.get().evaluate(user, request) == {
            "email": user.email,
            "email_verified": True,
        }
    default.refresh_from_db()
    assert default.expression == original_expression
    assert default.evaluate(user, request)["email_verified"] is False
    for provider in ProxyProvider.objects.all():
        application = Application.objects.get(provider=provider)
        expected_url = provider.external_host.rstrip("/") + "/"
        assert application.meta_launch_url == expected_url
        assert application.get_launch_url() == expected_url


check_mappings()
# Reproduce the duplicate relation found on the live Audiobookshelf provider.
for client_id in ("audiobookshelf", "grimmory"):
    provider = OAuth2Provider.objects.get(client_id=client_id)
    provider.property_mappings.add(default)
    Application.objects.filter(slug=client_id).update(
        meta_launch_url="https://auth.bovbel.com/incorrect/"
    )
    mappings = ScopeMapping.objects.filter(
        pk__in=provider.property_mappings.values("pk"), scope_name="email"
    )
    assert set(mappings) == {
        default,
        ScopeMapping.objects.get(name="nix-config email"),
    }, (
        client_id,
        list(mappings),
    )
assert Importer.from_string(blueprint).apply()
check_mappings()
# A subsequent application must remain idempotent.
assert Importer.from_string(blueprint).apply()
check_mappings()
print(
    "Authentik regression passed: launch URLs, grants, verified email claims, stale-mapping "
    "reconciliation, idempotence, and managed-mapping preservation."
)
