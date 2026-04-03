#!/bin/bash

# Simple GitHub App Token Generator using GitHub CLI
# Requires: gh CLI tool installed and authenticated

set -e

APP_ID="${1:-$OSGP_CI_APP_ID}"
INSTALLATION_ID="${2:-}"

if [ -z "$APP_ID" ]; then
    echo "❌ GitHub App ID is required"
    echo "Usage: $0 <app-id> [installation-id]"
    echo "   or: export OSGP_CI_APP_ID=<app-id> && $0"
    exit 1
fi

# Check if GitHub CLI is installed and authenticated
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed"
    echo "Install with: sudo apt install gh"
    echo "Or use the full generator: ./generate-github-app-token.sh"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "❌ GitHub CLI is not authenticated"
    echo "Run: gh auth login"
    exit 1
fi

echo "🚀 Generating GitHub App token using GitHub CLI..."

# Try to generate token using gh api
if [ -n "$INSTALLATION_ID" ]; then
    echo "📱 Using App ID: $APP_ID, Installation ID: $INSTALLATION_ID"
    TOKEN=$(gh api -X POST "/app/installations/$INSTALLATION_ID/access_tokens" --jq '.token' 2>/dev/null || echo "")
else
    echo "📱 Using App ID: $APP_ID (auto-detecting installation)"
    # Get installations first
    INSTALLATIONS=$(gh api "/app/installations" 2>/dev/null || echo "[]")
    INSTALLATION_ID=$(echo "$INSTALLATIONS" | jq -r '.[0].id // empty')

    if [ -z "$INSTALLATION_ID" ]; then
        echo "❌ No installations found for this app"
        echo "💡 Make sure the GitHub App is installed on your repositories"
        exit 1
    fi

    echo "🏗️  Found installation ID: $INSTALLATION_ID"
    TOKEN=$(gh api -X POST "/app/installations/$INSTALLATION_ID/access_tokens" --jq '.token' 2>/dev/null || echo "")
fi

if [ -z "$TOKEN" ]; then
    echo "❌ Failed to generate token using GitHub CLI"
    echo "💡 This might be because you're not authenticated as the GitHub App"
    echo "💡 Try using the full generator instead: ./generate-github-app-token.sh"
    exit 1
fi

echo "✅ Token generated successfully!"
echo "📋 Token length: ${#TOKEN} characters"
echo "⏰ Valid for: 1 hour"
echo
echo "🔑 Your GitHub App token:"
echo "$TOKEN"
echo
echo "💡 Test it with:"
echo "  ./test-github-app.sh $TOKEN smvdheijden/OSGP-Config"
