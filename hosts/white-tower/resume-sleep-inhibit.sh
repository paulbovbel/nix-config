#!/usr/bin/env bash
set -euo pipefail

systemd-inhibit --what=sleep --why='Post-resume grace period' --mode=block sleep 900
