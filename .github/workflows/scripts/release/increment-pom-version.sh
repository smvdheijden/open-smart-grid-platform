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

    # Test repository access before pushing
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

    # Test git remote access
    echo "::debug::Testing git remote access..."
    if git ls-remote "https://x-access-token:$TOKEN@github.com/$value.git" HEAD >/dev/null 2>&1; then
      echo "::debug::✅ Git remote access confirmed for $value"
    else
      echo "::error::❌ Git remote access failed for $value"
      echo "::debug::This usually indicates the GitHub App lacks Contents permission"
      exit 1
    fi

    # Debug: Show the push URL (mask token)
    echo "::debug::Pushing to: https://x-access-token:[MASKED]@github.com/$value.git"

    git remote -v
    git config --list | head -20

    # Temporarily disable URL rewrite that might interfere with token authentication
    original_insteadof=$(git config --get url."https://github.com/".insteadOf 2>/dev/null || echo "")
    if [ -n "$original_insteadof" ]; then
      echo "::debug::Temporarily removing URL rewrite rule: $original_insteadof -> https://github.com/"
      git config --unset url."https://github.com/".insteadOf
    fi

    # Store original remote URL and temporarily update it with token
    original_remote_url=$(git config --get remote.origin.url)
    echo "::debug::Original remote URL: $original_remote_url"
    git remote set-url origin "https://x-access-token:$TOKEN@github.com/$value.git"
    echo "::debug::Temporarily updated remote URL to use token"

    if [ "$DRY_RUN" = "true" ]; then
      git push --dry-run origin
    else
      git push origin
    fi

    # Restore original remote URL
    git remote set-url origin "$original_remote_url"
    echo "::debug::Restored original remote URL"

    # Restore URL rewrite rule if it existed
    if [ -n "$original_insteadof" ]; then
      echo "::debug::Restoring URL rewrite rule: $original_insteadof -> https://github.com/"
      git config url."https://github.com/".insteadOf "$original_insteadof"
    fi

    echo "::debug::Pushed pom version update"
  fi
done
