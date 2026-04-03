#!/bin/bash

ENV_FILE=$1
HOME_DIR=$2
RELEASE_VERSION=$3
NEW_MINOR_VERSION=$4
DRY_RUN=$5

echo "::debug:: Executing increment-pom-version.sh with parameters:"
echo "::debug:: ENV_FILE: $ENV_FILE"
echo "::debug:: HOME_DIR: $HOME_DIR"
echo "::debug:: RELEASE_VERSION: $RELEASE_VERSION"
echo "::debug:: NEW_MINOR_VERSION: $NEW_MINOR_VERSION"
echo "::debug:: DRY_RUN: $DRY_RUN"

# shellcheck source=../../.env
source "$ENV_FILE"

# Comprehensive token validation
if [ -z "$TOKEN" ]; then
  echo "::error::TOKEN is not set or empty!"
  echo "::debug::Available environment variables:"
  printenv | grep -E "(TOKEN|GITHUB)" | sed 's/=.*/=***/' || echo "No TOKEN-related vars found"
  exit 1
fi

echo "::debug::TOKEN is set (length: ${#TOKEN})"

# Test GitHub API access
echo "::debug::Testing GitHub API access..."
api_response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" https://api.github.com/installation/repositories)

if [ "$api_response" != "200" ]; then
  echo "::error::GitHub API authentication failed (HTTP $api_response)"
  echo "::debug::This indicates the token is invalid, expired, or lacks API access"
  exit 1
fi

echo "::debug::GitHub API authentication successful"

repositories=$(echo "$RELEASE_REPOSITORIES" | tr -d '[:space:]')

for value in ${repositories//,/ }
do
  if [[ ! $value =~ "b:" ]]; then
    cd "$HOME_DIR/$(echo "$value" | tr -d /)" || return
    echo "::debug:: Updating pom versions in $(echo "$value" | tr -d /)"
    poms=$(git ls-files '**pom.xml')

    if [ -z "$poms" ]; then
      echo "::notice::No pom.xml files found in $(echo "$value" | tr -d /). Skip incrementing pom versions."
      continue
    fi

    for pom in $poms
    do
      echo "::debug::Updating: $pom in $value"
      sed -i "s#<\\(osgp.[A-Za-z.-]*\\|shared.\\|smart.meter.[A-Za-z.-]*\\)\\?version>$RELEASE_VERSION#<\\1version>$NEW_MINOR_VERSION#g" "$pom"
      git add "$pom"
    done

    git commit -m "Adapted version to $NEW_MINOR_VERSION" || true
    status=$(git status 2>&1)
    echo "::debug::Git status: $status"


    # Debug: Show the push URL (mask token)
    echo "::debug::Pushing to: https://x-access-token:[MASKED]@github.com/$value.git"

    git remote -v
    git config --list | head -20

    # Store original remote URL and temporarily update it with token
    original_remote_url=$(git config --get remote.origin.url)
    echo "::notice::Original remote URL: $original_remote_url"
    git remote set-url origin "https://x-access-token:$TOKEN@github.com/$value.git"
    echo "::notice::Temporarily updated remote URL to use token"

    if [ "$DRY_RUN" = "true" ]; then
      git push --dry-run origin
    else
      git push origin
    fi

    # Restore original remote URL
    git remote set-url origin "$original_remote_url"
    echo "::debug::Restored original remote URL"

    echo "::debug::Pushed pom version update"
  fi
done
