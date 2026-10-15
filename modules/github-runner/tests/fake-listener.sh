#!/usr/bin/env bash
set -euo pipefail
case "$1" in
configure)
  [[ " $* " == *" --ephemeral "* ]]
  [[ " $* " == *" --pat ghp_validation-only "* ]]
  touch "$RUNNER_ROOT/.credentials" "$RUNNER_ROOT/.credentials_rsaparams" "$RUNNER_ROOT/.runner"
  ;;
run)
  touch /var/lib/github-runner/work/listening
  while [[ ! -f /var/lib/github-runner/work/finish ]]; do sleep 1; done
  exit "$(</var/lib/github-runner/work/finish)"
  ;;
*) exit 1 ;;
esac
