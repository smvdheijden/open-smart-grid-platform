#!/bin/bash

# Quick GitHub App Test Script
# Usage: ./test-github-app.sh <your-token> <repository>
# Example: ./test-github-app.sh ghs_xxxx smvdheijden/OSGP-Config

TOKEN="$1"
REPO="$2"

if [ -z "$TOKEN" ] || [ -z "$REPO" ]; then
    echo "Usage: $0 <github-app-token> <owner/repo>"
    echo "Example: $0 ghs_xxxx smvdheijden/OSGP-Config"
    exit 1
fi

echo "Testing GitHub App access to repository: $REPO"
echo "Token length: ${#TOKEN} characters"
echo

# Test 1: GitHub API App endpoint (GitHub Apps can't access /user endpoint)
echo "1. Testing GitHub API authentication..."
app_response=$(curl -s -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    https://api.github.com/installation/repositories)

if echo "$app_response" | grep -q '"total_count"'; then
    total_count=$(echo "$app_response" | grep -o '"total_count":[0-9]*' | cut -d':' -f2)
    echo "✅ Authenticated as GitHub App installation"
    echo "✅ App has access to $total_count repositories"
else
    echo "❌ Authentication failed"
    echo "Response: $app_response"
    # Check if it's the expected "Resource not accessible" error for /user endpoint
    if echo "$app_response" | grep -q "Resource not accessible by integration"; then
        echo "💡 Note: This is expected - GitHub Apps don't have access to /user endpoint"
        echo "🔄 Trying installation endpoint instead..."
        return 0  # Continue with other tests
    fi
    exit 1
fi

# Test 2: Repository access via API
echo
echo "2. Testing repository API access..."
repo_response=$(curl -s -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO")

if echo "$repo_response" | grep -q '"full_name"'; then
    echo "✅ Repository API access successful"
    permissions=$(echo "$repo_response" | grep -o '"permissions":{[^}]*}')
    echo "Permissions: $permissions"
else
    echo "❌ Repository API access failed"
    echo "Response: $repo_response"
fi

# Test 3: Git remote access
echo
echo "3. Testing git remote access..."
if git ls-remote "https://x-access-token:$TOKEN@github.com/$REPO.git" HEAD >/dev/null 2>&1; then
    echo "✅ Git remote access successful"
else
    echo "❌ Git remote access failed"
fi

# Test 4: Check specific repository access
echo
echo "4. Checking if target repository is in app installation..."

if echo "$app_response" | grep -q "\"name\":\"$(echo $REPO | cut -d'/' -f2)\""; then
    echo "✅ Target repository found in app installation"
else
    echo "❌ Target repository NOT found in app installation"
    echo "📋 Available repositories:"
    echo "$app_response" | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | head -10
    if [ $(echo "$app_response" | grep -o '"name":"[^"]*"' | wc -l) -gt 10 ]; then
        echo "... and more"
    fi
fi

echo
echo "=== Test Complete ==="
