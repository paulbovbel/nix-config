# Firefox Sync Server

This module runs Mozilla Sync Storage as a Podman container with a Postgres sidecar and public Caddy endpoint.

Secrets are stored in `secrets/server/firefox-syncserver-env.age`. Changing `SYNC_MASTER_SECRET` invalidates existing Firefox Sync tokens.

The secret file must provide:

```bash
POSTGRES_DB=syncserver
POSTGRES_USER=sync
POSTGRES_PASSWORD=...
SYNC_MASTER_SECRET=...
SYNC_TOKENSERVER__FXA_METRICS_HASH_SECRET=...
```

## Firefox Client Setup

Point Firefox at the token server endpoint:

```text
identity.sync.tokenserver.uri = https://firefox-sync.bovbel.com/token/1.0/sync/1.5
```
