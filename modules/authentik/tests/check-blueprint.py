"""Check the small VM fixture using Authentik's models and policy engine."""

import os
from pathlib import Path

from django.test import RequestFactory

from authentik.blueprints.v1.importer import Importer
from authentik.core.models import Application, Group, User
from authentik.policies.engine import PolicyEngine
from authentik.providers.oauth2.models import OAuth2Provider, ScopeMapping
from authentik.providers.proxy.models import ProxyProvider

blueprint = Path("/blueprints/custom/nix-config.yaml").read_text()
admin = User.objects.get(username="admin@example.test")
member = User.objects.get(username="member@example.test")
request = RequestFactory().get("/application/o/userinfo/")
request.user = member
managed_email = ScopeMapping.objects.get(
    managed="goauthentik.io/providers/oauth2/scope-email"
)
original_expression = managed_email.expression


def check_configuration():
    assert admin.is_superuser and not member.is_superuser
    assert (
        os.environ["AUTHENTIK_CONFIDENTIAL_CLIENT_SECRET"]
        == "test-existing-client-secret"
    )
    assert len(os.environ["AUTHENTIK_FRESH_CLIENT_SECRET"]) == 64
    email = ScopeMapping.objects.get(name="nix-config email")
    for client_id in ("native", "confidential", "fresh"):
        provider = OAuth2Provider.objects.get(client_id=client_id)
        assert provider.grant_types == ["authorization_code", "refresh_token"]
        mappings = ScopeMapping.objects.filter(
            pk__in=provider.property_mappings.values("pk"), scope_name="email"
        )
        assert list(mappings) == [email]
        assert email.evaluate(member, request) == {
            "email": member.email,
            "email_verified": True,
        }
        if client_id != "native":
            assert (
                provider.client_secret
                == os.environ[f"AUTHENTIK_{client_id.upper()}_CLIENT_SECRET"]
            )
    managed_email.refresh_from_db()
    assert managed_email.expression == original_expression
    assert managed_email.evaluate(member, request)["email_verified"] is False

    visible = list(Application.objects.filter(meta_hide=False))
    assert len(visible) == 6
    assert len({app.get_launch_url() for app in visible}) == 6
    for app in visible:
        assert app.meta_icon.startswith("https://") and app.meta_icon.endswith(".svg")
        assert app.get_launch_url().startswith("https://apps.example.test:8443/")
    native = Application.objects.get(slug="native")
    assert native.provider_id is not None
    assert native.get_launch_url() == "https://apps.example.test:8443/native/"
    assert native.meta_icon == "https://icons.example.test/native.svg"
    home = Application.objects.get(slug="caddy-demo-home")
    assert home.provider_id is None
    assert home.get_launch_url() == "https://apps.example.test:8443/"
    assert not Application.objects.filter(slug="caddy-demo-api").exists()
    assert not Application.objects.filter(slug="caddy-demo-native").exists()
    assert ProxyProvider.objects.count() == 2
    for provider in ProxyProvider.objects.all():
        app = Application.objects.get(provider=provider)
        assert app.meta_hide
        assert app.get_launch_url() == provider.external_host.rstrip("/") + "/"


check_configuration()
# A missing environment value must fail validation without changing existing applications.
secret = os.environ.pop("AUTHENTIK_CONFIDENTIAL_CLIENT_SECRET")
assert not Importer.from_string(blueprint).apply()
os.environ["AUTHENTIK_CONFIDENTIAL_CLIENT_SECRET"] = secret
check_configuration()

# Simulate stale UI state, including the duplicate email relation encountered in production.
for client_id in ("native", "confidential", "fresh"):
    provider = OAuth2Provider.objects.get(client_id=client_id)
    provider.property_mappings.add(managed_email)
    provider.grant_types = ["authorization_code"]
    provider.save()
Application.objects.filter(slug__in=("native", "caddy-demo-member")).update(
    meta_launch_url="https://incorrect.example.test/", meta_icon="", meta_hide=True
)
assert Importer.from_string(blueprint).apply()
check_configuration()
assert Importer.from_string(blueprint).apply()
check_configuration()


def can_see(slug, user):
    engine = PolicyEngine(Application.objects.get(slug=slug), user)
    engine.use_cache = False
    engine.build()
    return engine.passing


assert can_see("caddy-demo-member", member)
assert not can_see("caddy-demo-admin", member)
assert can_see("caddy-demo-admin", admin)
assert can_see("caddy-demo-home", member)
outsider = User.objects.create(username="outsider", email="outsider@example.test")
outsider.groups.add(Group.objects.get(name="user"), Group.objects.get(name="admin"))
assert not can_see("caddy-demo-admin", outsider)
assert not can_see("caddy-demo-home", outsider)
print(
    "Blueprint checks passed: credentials, claims, dashboard, visibility, and reconciliation."
)
