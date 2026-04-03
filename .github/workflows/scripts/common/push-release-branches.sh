#!/bin/bash

ENV_FILE=$1
HOME_DIR=$2
RELEASE_VERSION=$3
DRY_RUN=$4

echo "::debug:: Executing push-release-branches.sh with parameters:"
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
    echo "::notice::pushing release branch $release_branch"
    echo "::debug::in $HOME_DIR/$(echo "$value" | tr -d /)"

    current_branch=$(git rev-parse --abbrev-ref HEAD)
    echo "::debug:: current branch: $current_branch"

    git checkout -f $release_branch
    echo "::debug::switched to branch: $release_branch"

    # Test repository access if token is available
    if [ -n "$TOKEN" ]; then
      echo "::debug::Testing repository access for: $value"
      repo_response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github+json" "https://api.github.com/repos/$value")

      if [ "$repo_response" = "200" ]; then
        echo "::debug::✅ API access to repository $value confirmed"
      elif [ "$repo_response" = "404" ]; then
        echo "::error::❌ Repository $value not found or token lacks access"
        exit 1
      elif [ "$repo_response" = "403" ]; then
        echo "::error::❌ Token lacks permission for repository $value"
        echo "::debug::Check if the GitHub App is installed on $value with Contents: Write permission"
        exit 1
      else
        echo "::warning::Unexpected API response for $value (HTTP $repo_response)"
      fi
    fi

    status=$(git status 2>&1)
    echo "::debug:: git status: $status"

    if [ "$DRY_RUN" = "true" ]; then
      git push --dry-run --set-upstream origin "$release_branch"
      echo "::debug:: dry-run push completed for release branch: $release_branch"
    else
      git push --set-upstream origin "$release_branch"
      echo "::debug:: pushed release branch: $release_branch"
    fi

    git checkout $current_branch
    echo "::debug:: switched back to branch: $current_branch"
  fi
done
