#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  printf 'usage: %s <target> <remote-root> <paths-json>\n' "$0" >&2
  exit 2
fi

target=$1
remote_root=$2
paths_json=$3

known_hosts="${STATE_DIRECTORY:?}/known_hosts"
ssh_command=(
  ssh
  -o BatchMode=yes
  -o StrictHostKeyChecking=accept-new
  -o UserKnownHostsFile="$known_hosts"
)

if [[ -n ${IDENTITY_FILE:-} ]]; then
  ssh_command+=(-i "$IDENTITY_FILE")
fi

printf -v RSYNC_RSH '%q ' "${ssh_command[@]}"
export RSYNC_RSH

echo "[backup] backup to $target started"
backup_start=$(date +%s)
total_size=0

while IFS= read -r path; do
  name=$(jq --raw-output '.name' <<<"$path")
  source=$(jq --raw-output '.source' <<<"$path")

  test -e "$source"

  du_args=(--summarize --block-size=1)
  while IFS= read -r pattern; do
    du_args+=(--exclude "$pattern")
  done < <(jq --raw-output '.excludes[]' <<<"$path")

  size=$(du "${du_args[@]}" -- "$source" | cut -f1)
  total_size=$((total_size + size))
  human_size=$(numfmt --to=iec-i --suffix=B "$size")

  echo "[backup] size $name: $human_size ($size bytes) $source"
done < <(jq --compact-output '.[]' "$paths_json")

human_total_size=$(numfmt --to=iec-i --suffix=B "$total_size")
echo "[backup] total size: $human_total_size ($total_size bytes)"

while IFS= read -r path; do
  name=$(jq --raw-output '.name' <<<"$path")
  source=$(jq --raw-output '.source' <<<"$path")
  destination=$(jq --raw-output '.destination' <<<"$path")
  remote="$target:$remote_root/$destination/"
  remote_dir="$remote_root/$destination"

  test -e "$source"

  sync_source=$source
  if [[ -d $sync_source ]]; then
    sync_source="$sync_source/"
  fi

  rsync_args=(
    --archive
    --hard-links
    --delete
    --numeric-ids
    --human-readable
    --stats
  )

  while IFS= read -r pattern; do
    rsync_args+=(--exclude "$pattern")
  done < <(jq --raw-output '.excludes[]' <<<"$path")

  echo "[backup] starting $name: $source -> $remote"
  path_start=$(date +%s)

  "${ssh_command[@]}" -n "$target" mkdir -p -- "$remote_dir"

  if ! rsync "${rsync_args[@]}" "$sync_source" "$remote"; then
    echo "[backup] failed $name: $remote" >&2
    exit 1
  fi

  path_end=$(date +%s)
  echo "[backup] finished $name: $remote in $((path_end - path_start))s"
done < <(jq --compact-output '.[]' "$paths_json")

backup_end=$(date +%s)
echo "[backup] backup to $target finished in $((backup_end - backup_start))s"
