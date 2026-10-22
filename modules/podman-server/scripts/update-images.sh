#!/usr/bin/env bash
set -euo pipefail

catalog=images.Dockerfile
temporary=$(mktemp "${catalog}.XXXXXX")
trap 'rm -f "$temporary"' EXIT

while IFS= read -r line || [[ -n $line ]]; do
  if [[ $line =~ ^FROM\ ([^[:space:]@]+)@sha256:[a-f0-9]{64}\ AS\ ([^[:space:]]+)$ ]]; then
    image=${BASH_REMATCH[1]}
    alias=${BASH_REMATCH[2]}
    digest=$(skopeo inspect --raw "docker://$image" | skopeo manifest-digest /dev/stdin)
    if [[ ! $digest =~ ^sha256:[a-f0-9]{64}$ ]]; then
      echo "Invalid digest for $image: $digest" >&2
      exit 1
    fi
    echo "Resolved $alias: $digest" >&2
    printf 'FROM %s@%s AS %s\n' "$image" "$digest" "$alias" >>"$temporary"
  elif [[ $line == FROM* ]]; then
    echo "Unsupported catalog entry: $line" >&2
    exit 1
  else
    printf '%s\n' "$line" >>"$temporary"
  fi
done <"$catalog"

# Do not touch the catalog unless every lookup succeeded.
cat "$temporary" >"$catalog"
