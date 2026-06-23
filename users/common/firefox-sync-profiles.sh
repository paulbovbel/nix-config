#!/usr/bin/env bash
set -euo pipefail

tokenserver_uri=${FIREFOX_SYNC_TOKENSERVER_URI:?}

configure_profile() {
  local profile_dir=$1
  local user_js=$profile_dir/user.js
  local tmp

  tmp=$(mktemp)

  if [[ -f $user_js ]]; then
    grep -v '^user_pref("identity\.sync\.tokenserver\.uri",' "$user_js" >"$tmp" || true
  fi

  printf 'user_pref("identity.sync.tokenserver.uri", "%s");\n' "$tokenserver_uri" >>"$tmp"
  install -m 0600 "$tmp" "$user_js"
  rm -f "$tmp"
}

configure_root() {
  local root=$1

  [[ -d $root ]] || return 0

  while IFS= read -r -d '' profile_dir; do
    configure_profile "$profile_dir"
  done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -name '*.default*' -print0)
}

configure_root "$HOME/.mozilla/firefox"
configure_root "$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox"
