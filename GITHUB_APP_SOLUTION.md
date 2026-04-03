# GitHub App Permission Issue - Comprehensive Solution Guide

## Problem Summary
Your workflow succeeds when pushing to `open-smart-grid-platform` but fails with 403 errors when pushing to `OSGP-Config` and `OSGP-Documentation` repositories.

## Root Cause Analysis Tools

### 1. Immediate Testing
Run this command in your workflow or locally to test your GitHub App token:
```bash
# Replace YOUR_TOKEN and REPO_NAME with actual values
./test-github-app.sh YOUR_TOKEN smvdheijden/OSGP-Config
```

### 2. Workflow Diagnostics
The enhanced scripts now include comprehensive validation that will:
- ✅ Verify TOKEN is set and valid
- ✅ Test GitHub API authentication
- ✅ Check repository access via API
- ✅ Test git remote access
- ✅ Verify app installation scope

## Most Likely Causes & Solutions

### Cause 1: App Installation Scope ⭐ MOST LIKELY
**Problem**: GitHub App not installed on target repositories
**Solution**: 
1. Go to GitHub Settings → Developer settings → GitHub Apps → Your App
2. Click "Install App" 
3. Select your account (smvdheijden)
4. Ensure ALL target repositories are selected:
   - ✅ smvdheijden/open-smart-grid-platform
   - ✅ smvdheijden/OSGP-Config  
   - ✅ smvdheijden/OSGP-Documentation
5. Save the installation

### Cause 2: Token Generation Context
**Problem**: Token generated for wrong installation or context
**Solution**: 
- The `actions/create-github-app-token@v3.0.0` action should automatically handle this
- Verify your secrets `OSGP_CI_APP_ID` and `OSGP_CI_APP_PRIVATE_KEY` are correct

### Cause 3: Repository Names in .env
**Problem**: .env file contains incorrect repository references
**Solution**: 
Since I cannot read your .env file, verify it contains:
```
RELEASE_REPOSITORIES=smvdheijden/open-smart-grid-platform,smvdheijden/OSGP-Config,smvdheijden/OSGP-Documentation
```
NOT the upstream repository names.

### Cause 4: App Permissions
**Problem**: Missing or insufficient permissions
**Solution**: 
1. Go to your GitHub App settings
2. Under "Repository permissions", ensure:
   - Contents: **Read and write** ✅
   - Metadata: **Read** ✅
3. Save changes and reinstall the app if prompted

## Step-by-Step Resolution Process

### Step 1: Verify App Installation ⭐ START HERE
1. Go to https://github.com/settings/installations
2. Find your GitHub App (osgp-ci-test)
3. Click "Configure"
4. Verify repository access includes ALL target repos
5. If not, add them and save

### Step 2: Test Token Locally
1. Generate a token using GitHub CLI or your app's private key
2. Run: `./test-github-app.sh <token> smvdheijden/OSGP-Config`
3. Check if all tests pass

### Step 3: Run Enhanced Workflow
1. Commit the enhanced diagnostic scripts
2. Run your workflow with dry_run: true
3. Check the workflow logs for detailed diagnostic output

### Step 4: Analyze Results
The enhanced scripts will tell you exactly what's wrong:
- ❌ "Repository not found or token lacks access" → App not installed on repo
- ❌ "Token lacks permission" → App needs Contents: Write permission  
- ❌ "API authentication failed" → Invalid/expired token
- ❌ "Git remote access failed" → Network or auth issue

## Quick Verification Commands

If you have access to a GitHub App token, test immediately:

```bash
# Test API access
curl -H "Authorization: Bearer YOUR_TOKEN" https://api.github.com/user

# Test repository access  
curl -H "Authorization: Bearer YOUR_TOKEN" https://api.github.com/repos/smvdheijden/OSGP-Config

# Test git access
git ls-remote https://x-access-token:YOUR_TOKEN@github.com/smvdheijden/OSGP-Config.git
```

## Expected Behavior After Fix

When everything is working correctly:
1. ✅ Token authenticates with GitHub API
2. ✅ API shows access to all target repositories  
3. ✅ Git remote access succeeds for all repos
4. ✅ Push operations complete successfully
5. ✅ Commits appear as authored by your GitHub App (osgp-ci-test[bot])

## Need More Help?

If the issue persists after following this guide:
1. Run the diagnostic script and share the output
2. Share the specific error messages from your workflow logs
3. Confirm your app installation configuration

The enhanced diagnostic scripts will provide the exact information needed to pinpoint and resolve the remaining issues.
