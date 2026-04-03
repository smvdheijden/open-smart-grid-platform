#!/bin/bash

# GitHub App Diagnostic Script
# This script will help diagnose GitHub App authentication issues

echo "=== GitHub App Authentication Diagnostics ==="
echo "Date: $(date)"
echo

# Check if TOKEN is set
echo "1. TOKEN Environment Variable:"
if [ -z "$TOKEN" ]; then
    echo "❌ TOKEN is NOT set or empty"
    echo "This is likely the root cause of your permission issues"
else
    echo "✅ TOKEN is set (length: ${#TOKEN} characters)"
    # Show first/last few chars for verification without exposing the token
    echo "Token preview: ${TOKEN:0:4}...${TOKEN: -4}"
fi
echo

# Check git configuration
echo "2. Git Configuration:"
echo "Git user.name: $(git config --global user.name)"
echo "Git user.email: $(git config --global user.email)"
echo

echo "3. Git URL Rewrite Rules:"
git config --global --get-regexp url
echo

# Check current directory and git remote
echo "4. Current Repository State:"
echo "Current directory: $(pwd)"
echo "Git remotes:"
git remote -v 2>/dev/null || echo "❌ Not in a git repository or no remotes configured"
echo

# Test GitHub API access with the token
echo "5. GitHub API Test:"
if [ -n "$TOKEN" ]; then
    echo "Testing API access..."
    response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github+json" \
        https://api.github.com/installation/repositories)

    if [ "$response" = "200" ]; then
        echo "✅ Token can authenticate with GitHub API (GitHub App)"
        # Get installation info to verify which repositories the app has access to
        install_info=$(curl -s -H "Authorization: Bearer $TOKEN" \
            -H "Accept: application/vnd.github+json" \
            https://api.github.com/installation/repositories)
        repo_count=$(echo "$install_info" | grep -o '"total_count":[0-9]*' | cut -d':' -f2)
        echo "App has access to: $repo_count repositories"
    else
        echo "❌ Token authentication failed (HTTP $response)"
        echo "This indicates the token is invalid, expired, or malformed"
    fi
else
    echo "⚠️  Skipping API test - no token available"
fi
echo

# Test repository access
echo "6. Repository Access Test:"
if [ -n "$TOKEN" ] && [ -n "$1" ]; then
    repo="$1"
    echo "Testing access to repository: $repo"

    response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$repo")

    if [ "$response" = "200" ]; then
        echo "✅ Token can access repository $repo"
    elif [ "$response" = "404" ]; then
        echo "❌ Repository $repo not found or token lacks access"
    elif [ "$response" = "403" ]; then
        echo "❌ Token lacks permission for repository $repo"
    else
        echo "❌ Unexpected response for $repo (HTTP $response)"
    fi
else
    echo "⚠️  Skipping repository test - provide repo name as argument (e.g., owner/repo)"
fi
echo

# Check git push simulation
echo "7. Git Push Simulation:"
if [ -n "$TOKEN" ] && [ -n "$1" ]; then
    repo="$1"
    echo "Simulating git push to: $repo"
    echo "Push URL would be: https://x-access-token:[MASKED]@github.com/$repo.git"

    # Test if we can at least fetch from this URL
    git ls-remote "https://x-access-token:$TOKEN@github.com/$repo.git" HEAD 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "✅ Token can access git remote for $repo"
    else
        echo "❌ Token cannot access git remote for $repo"
    fi
else
    echo "⚠️  Provide repository name to test git access"
fi
echo

echo "=== Diagnostic Summary ==="
echo "Run this script with: bash diagnose-github-app.sh owner/repo"
echo "Replace 'owner/repo' with your actual repository name"
echo
