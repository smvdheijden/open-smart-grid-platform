#!/bin/bash

ENV_FILE=$1
HOME_DIR=$2
RELEASE_VERSION=$3
DRY_RUN=$4

echo "::debug:: Executing push-changes.sh with parameters:"
echo "::debug:: ENV_FILE: $ENV_FILE"
echo "::debug:: HOME_DIR: $HOME_DIR"
echo "::debug:: RELEASE_VERSION: $RELEASE_VERSION"
echo "::debug:: DRY_RUN: $DRY_RUN"

# shellcheck source=../../.env
source "$ENV_FILE"

repositories=$(echo "$RELEASE_REPOSITORIES" | tr -d '[:space:]')
release_branch=${RELEASE_BRANCH_PREFIX}$RELEASE_VERSION

for value in ${repositories//,/ }
do
  if [[ ! $value =~ "b:" ]]; then
    cd "$HOME_DIR/$(echo "$value" | tr -d /)" || return
    echo "::notice::pushing changes"
    echo "::debug::in $HOME_DIR/$(echo "$value" | tr -d /)"

    status=$(git status 2>&1)
    echo "::debug:: git status: $status"

    if [ "$DRY_RUN" = "true" ]; then
      echo "::debug::Dry-run pushing version increment"
      git push --dry-run
      echo "::debug::Dry-run pushing release branch: $release_branch"
      git push --dry-run --set-upstream origin "$release_branch"
      echo "::debug::Finished dry-run for pushing changes"
    else
      echo "::debug::Push version increment"
      git push
      echo "::debug::Push release branch: $release_branch"
      git push --set-upstream origin "$release_branch"
      echo "::debug::Finished pushing changes: $release_branch"
    fi
  fi
done
