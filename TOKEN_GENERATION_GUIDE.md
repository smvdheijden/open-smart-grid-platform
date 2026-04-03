# GitHub App Token Generation for Local Testing

## Quick Start Options

### Option 1: Full Token Generator (Recommended)
```bash
# 1. Create private key file from your secret
echo "$OSGP_CI_APP_PRIVATE_KEY" > private-key.pem

# 2. Generate token
export OSGP_CI_APP_ID=your-app-id
./generate-github-app-token.sh

# 3. Test the token
TOKEN=$(./generate-github-app-token.sh | tail -1)
./test-github-app.sh $TOKEN smvdheijden/OSGP-Config
```

### Option 2: Using GitHub CLI (if available)
```bash
# 1. Install and authenticate GitHub CLI
sudo apt install gh
gh auth login

# 2. Generate token (may not work if not authenticated as app)
./generate-token-gh.sh your-app-id
```

### Option 3: Manual with curl (if you know your installation ID)
```bash
# 1. Generate JWT manually
# 2. Get installation ID
# 3. Exchange for access token
# (See full script for implementation)
```

## Prerequisites

### Required Tools
```bash
# Install dependencies
sudo apt-get update
sudo apt-get install openssl curl jq

# Optional: GitHub CLI
sudo apt install gh
```

### Required Information
- GitHub App ID (from your app settings)
- GitHub App private key (from your app settings)
- Installation ID (auto-detected by script)

## Step-by-Step Process

### 1. Get Your App Credentials
1. Go to GitHub Settings → Developer settings → GitHub Apps
2. Click on your app (osgp-ci-test)
3. Note the App ID
4. Generate and download a private key

### 2. Set Up Environment
```bash
# Export your app ID
export OSGP_CI_APP_ID=123456

# Create private key file
echo "$OSGP_CI_APP_PRIVATE_KEY" > private-key.pem
chmod 600 private-key.pem
```

### 3. Generate Token
```bash
# Using the full generator
./generate-github-app-token.sh

# Or with explicit parameters
./generate-github-app-token.sh --app-id 123456 --private-key private-key.pem
```

### 4. Test Token
```bash
# Test with your repositories
./test-github-app.sh $TOKEN smvdheijden/open-smart-grid-platform
./test-github-app.sh $TOKEN smvdheijden/OSGP-Config
./test-github-app.sh $TOKEN smvdheijden/OSGP-Documentation
```

### 5. Use Token
```bash
# Set as environment variable for your scripts
export TOKEN=$generated_token

# Or use directly in git commands
git clone https://x-access-token:$TOKEN@github.com/smvdheijden/OSGP-Config.git

# Test push access
cd OSGP-Config
echo "test" > test.txt
git add test.txt
git commit -m "Test commit"
git push https://x-access-token:$TOKEN@github.com/smvdheijden/OSGP-Config.git
```

## Troubleshooting

### Token Generation Fails
- ✅ Check App ID is correct
- ✅ Check private key file exists and is valid
- ✅ Verify app is installed on target repositories
- ✅ Check network connectivity

### Permission Denied (403)
- ✅ Verify app has "Contents: Read and write" permission
- ✅ Check app is installed on the specific repository
- ✅ Confirm token is not expired (valid for 1 hour)

### Repository Not Found (404)
- ✅ Check repository name format (owner/repo)
- ✅ Verify app installation includes the repository
- ✅ Confirm repository exists and is accessible

## Security Notes

- 🔒 Tokens expire after 1 hour
- 🔒 Keep private keys secure (chmod 600)
- 🔒 Don't commit tokens or private keys to git
- 🔒 Use tokens only for testing, not production

## Quick Test Commands

```bash
# Generate and test in one go
TOKEN=$(./generate-github-app-token.sh | tail -1)
echo "Testing token: ${TOKEN:0:8}..."
./test-github-app.sh $TOKEN smvdheijden/OSGP-Config

# Test all your repositories
for repo in "smvdheijden/open-smart-grid-platform" "smvdheijden/OSGP-Config" "smvdheijden/OSGP-Documentation"; do
    echo "Testing $repo..."
    ./test-github-app.sh $TOKEN $repo
done
```

This should give you a working GitHub App token for local testing and help you verify that your app permissions are correctly configured.
