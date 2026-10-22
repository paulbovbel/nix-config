#!/usr/bin/env bash
set -euo pipefail

: "${GH_TOKEN:?Set GH_TOKEN to read dependency PRs}"
: "${GH_REPO:?Set GH_REPO to the target repository}"
branch=automation/dependencies
url=$(gh pr list --head "$branch" --base main --state open --json url --jq '.[0].url // empty')
if [[ ${UPDATE_EVENT:?} == push && -z $url ]]; then
  echo 'No dependency PR to sync.'
  echo 'active=false' >>"$GITHUB_OUTPUT"
  exit 0
fi

git config user.name 'github-actions[bot]'
git config user.email '41898282+github-actions[bot]@users.noreply.github.com'
if [[ -n $url ]]; then
  git -c credential.helper= -c 'credential.helper=!gh auth git-credential' \
    fetch origin "refs/heads/$branch"
  git checkout -b dependency-update-work FETCH_HEAD
  # Preserve reviewed dependency changes while bringing the PR up to main.
  # Conflicts fail visibly instead of overwriting either side.
  git merge --no-edit origin/main
  # Give create-pull-request an uncommitted diff on its consistent base.
  git checkout main
  git diff --binary origin/main dependency-update-work | git apply --binary
fi
echo 'active=true' >>"$GITHUB_OUTPUT"
