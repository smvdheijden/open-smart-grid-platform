#!/bin/bash

# GitHub App Token Generator for Local Testing
# This script generates a GitHub App installation access token using your app's private key

set -e

# Configuration - Update these values
APP_ID="${OSGP_CI_APP_ID:-}"
PRIVATE_KEY_FILE="${OSGP_CI_APP_PRIVATE_KEY_FILE:-private-key.pem}"
INSTALLATION_ID="${INSTALLATION_ID:-}"

# Check if required tools are installed
check_dependencies() {
    local missing_deps=()

    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
    fi

    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi

    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "❌ Missing dependencies: ${missing_deps[*]}"
        echo "Install with: sudo apt-get install ${missing_deps[*]}"
        exit 1
    fi
}

# Base64URL encoding (without padding)
base64url() {
    openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

# Generate JWT token
generate_jwt() {
    local app_id="$1"
    local private_key_file="$2"

    if [ ! -f "$private_key_file" ]; then
        echo "❌ Private key file not found: $private_key_file"
        echo "💡 Create it with: echo \"\$OSGP_CI_APP_PRIVATE_KEY\" > private-key.pem"
        exit 1
    fi

    # JWT Header
    local header='{"alg":"RS256","typ":"JWT"}'

    # JWT Payload
    local iat=$(date +%s)
    local exp=$((iat + 540)) # 9 minutes (max 10 minutes)
    local payload="{\"iat\":$iat,\"exp\":$exp,\"iss\":$app_id}"

    # Encode header and payload
    local header_b64=$(echo -n "$header" | base64url)
    local payload_b64=$(echo -n "$payload" | base64url)
    local unsigned_token="$header_b64.$payload_b64"

    # Sign with private key
    local signature=$(echo -n "$unsigned_token" | openssl dgst -sha256 -sign "$private_key_file" | base64url)

    echo "$unsigned_token.$signature"
}

# Get installation ID
get_installation_id() {
    local jwt="$1"

    echo "🔍 Finding installation ID..."

    local installations=$(curl -s -H "Authorization: Bearer $jwt" \
        -H "Accept: application/vnd.github+json" \
        https://api.github.com/app/installations)

    if ! echo "$installations" | jq -e '.[0].id' >/dev/null 2>&1; then
        echo "❌ Failed to get installations or no installations found"
        echo "Response: $installations"
        exit 1
    fi

    echo "$installations" | jq -r '.[0].id'
}

# Generate installation access token
generate_installation_token() {
    local jwt="$1"
    local installation_id="$2"

    echo "🔑 Generating installation access token..."

    local response=$(curl -s -X POST \
        -H "Authorization: Bearer $jwt" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/app/installations/$installation_id/access_tokens")

    if ! echo "$response" | jq -e '.token' >/dev/null 2>&1; then
        echo "❌ Failed to generate installation token"
        echo "Response: $response"
        exit 1
    fi

    echo "$response" | jq -r '.token'
}

# Show usage
show_usage() {
    cat << EOF
GitHub App Token Generator

Usage: $0 [options]

Options:
  -a, --app-id ID           GitHub App ID (or set OSGP_CI_APP_ID env var)
  -k, --private-key FILE    Path to private key file (default: private-key.pem)
  -i, --installation-id ID  Installation ID (optional, will auto-detect if not provided)
  -h, --help               Show this help

Environment Variables:
  OSGP_CI_APP_ID                 GitHub App ID
  OSGP_CI_APP_PRIVATE_KEY_FILE   Path to private key file
  INSTALLATION_ID                Installation ID

Examples:
  # Using command line arguments
  $0 --app-id 123456 --private-key my-key.pem

  # Using environment variables
  export OSGP_CI_APP_ID=123456
  echo "\$OSGP_CI_APP_PRIVATE_KEY" > private-key.pem
  $0

  # Test the generated token
  TOKEN=\$($0)
  ./test-github-app.sh \$TOKEN smvdheijden/OSGP-Config
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -a|--app-id)
            APP_ID="$2"
            shift 2
            ;;
        -k|--private-key)
            PRIVATE_KEY_FILE="$2"
            shift 2
            ;;
        -i|--installation-id)
            INSTALLATION_ID="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "🚀 GitHub App Token Generator"
    echo "=============================="

    # Check dependencies
    check_dependencies

    # Validate required parameters
    if [ -z "$APP_ID" ]; then
        echo "❌ GitHub App ID is required"
        echo "💡 Set OSGP_CI_APP_ID environment variable or use --app-id option"
        exit 1
    fi

    echo "📱 App ID: $APP_ID"
    echo "🔐 Private Key: $PRIVATE_KEY_FILE"

    # Generate JWT
    echo "🔧 Generating JWT..."
    JWT=$(generate_jwt "$APP_ID" "$PRIVATE_KEY_FILE")

    # Get installation ID if not provided
    if [ -z "$INSTALLATION_ID" ]; then
        INSTALLATION_ID=$(get_installation_id "$JWT")
    fi

    echo "🏗️  Installation ID: $INSTALLATION_ID"

    # Generate installation token
    TOKEN=$(generate_installation_token "$JWT" "$INSTALLATION_ID")

    echo "✅ Token generated successfully!"
    echo "📋 Token length: ${#TOKEN} characters"
    echo "⏰ Valid for: 1 hour"
    echo
    echo "🔑 Your GitHub App token:"
    echo "$TOKEN"
    echo
    echo "💡 Test it with:"
    echo "  ./test-github-app.sh $TOKEN smvdheijden/OSGP-Config"
    echo
    echo "💡 Use in git commands:"
    echo "  git clone https://x-access-token:$TOKEN@github.com/smvdheijden/OSGP-Config.git"
}

main "$@"
