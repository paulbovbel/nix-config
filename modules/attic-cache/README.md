# Attic Cache

This module runs the Attic server and watch-store client, but cache creation and token generation are manual.

## Requirements

The server requires shared storage, the root filesystem volume abstraction, Caddy ingress, and agenix-managed server credentials. The watch-store client requires its own push token.

## Persistence

Attic metadata is stored in `storage.datasets.app.children.attic`; cache objects are stored in `rootFs.volumes.attic`. Both paths must be available before `atticd` starts. The watch-store client uses systemd-managed state to remember upload progress.

## Initialize a New Cache

1. Deploy the host with `atticCache.enable = true` and verify `atticd` is reachable at the public endpoint.

2. On the cache host, load the server signing secret and find the active `atticd` config:

   ```bash
   set -a
   . /run/agenix/attic-server-env
   set +a

   systemctl cat atticd
   ```

3. Copy the `--config` path from the `atticd` `ExecStart`, then generate a short-lived admin token:

   ```bash
   config_path=/nix/store/...-atticd.toml
   admin_token="$(nix shell nixpkgs#attic-server -c atticadm -f "$config_path" make-token --sub admin --validity '1 hour' --pull '*' --push '*' --create-cache '*' --configure-cache '*')"
   ```

4. Log in to the server. These values match the module defaults:

   ```bash
   attic login --set-default bovbel https://nix-cache.bovbel.com/ "$admin_token"
   ```

5. Create the cache if it does not already exist:

   ```bash
   attic cache info bovbel:nixos >/dev/null || attic cache create --public --priority 41 bovbel:nixos
   ```

6. Confirm the cache is available:

   ```bash
   attic cache info bovbel:nixos
   ```

7. Generate the watch-store client token and rekey the agenix secret:

   ```bash
   client_token="$(nix shell nixpkgs#attic-server -c atticadm -f "$config_path" make-token --sub watch-store --validity '1 year' --pull nixos --push nixos)"
   printf '%s\n' "$client_token"
   agenix -e secrets/common/attic-watch-store-token.age
   agenix -r
   ```

8. Unset tokens from the shell when finished:

   ```bash
   unset admin_token client_token ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64 ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64
   ```

## Full Cache Reset

This permanently removes all Attic cache metadata and objects. Stop both the
uploader and server, verify that the expected ZFS datasets are mounted, then
empty them:

```bash
sudo systemctl stop attic-watch-store.service atticd.service

mountpoint -q /storage/app/attic
mountpoint -q /var/lib/attic/storage

sudo find /storage/app/attic -mindepth 1 -delete
sudo find /var/lib/attic/storage -mindepth 1 -delete

sudo systemctl start atticd.service
```

The reset removes the cache definition along with the database. Repeat the
admin-token and cache-creation steps above, then restart the uploader:

```bash
attic cache create --public --priority 41 bovbel:nixos
sudo systemctl start attic-watch-store.service
```

## Troubleshooting

Inspect `atticd.service` for database or mount failures and use `systemctl cat atticd.service` to locate its generated `atticd.toml`. Metadata and the SQLite database live at `/storage/app/attic/server.db`; cache objects live on `zroot/root/attic` mounted at `/var/lib/attic/storage`. Inspect `attic-watch-store.service` and its state directory `/var/lib/attic-watch-store` for token or upload failures, and test the local server on port 8080 before debugging the Caddy endpoint.
