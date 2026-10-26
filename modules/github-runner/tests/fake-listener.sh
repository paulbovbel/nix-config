#!/usr/bin/env bash
set -euo pipefail
case "$1" in
configure)
  [[ " $* " == *" --ephemeral "* ]]
  [[ " $* " == *" --pat ghp_validation-only "* ]]
  touch "$RUNNER_ROOT/.credentials" "$RUNNER_ROOT/.credentials_rsaparams" "$RUNNER_ROOT/.runner"
  ;;
run)
  command -v git-lfs >/dev/null
  [[ "$NIX_SSHOPTS" == "-i /run/agenix/github-runner-ssh-key -o IdentitiesOnly=yes" ]]
  [[ "$GIT_SSH_COMMAND" == *"/bin/ssh $NIX_SSHOPTS" ]]
  [[ -r /run/agenix/github-runner-ssh-key ]]
  touch /var/lib/github-runner/work/listening
  while [[ ! -f /var/lib/github-runner/work/finish ]]; do sleep 1; done
  exit "$(</var/lib/github-runner/work/finish)"
  ;;
*) exit 1 ;;
esac
