#!/bin/bash
set -e

# ===== CONFIGURATION =====
GITLAB_URL="https://devcloud.ubs.net"
GROUP_PATH="devops/platform/infra"   # 👈 Full path to subgroup
PROJECT_NAME="my-new-repo"           # 👈 Name of new repo/project
BRANCHES=("dev" "qa" "prod")         # 👈 Branches to create
DEFAULT_BRANCH="main"                # 👈 Default branch name
# ==========================

if [[ -z "$GITLAB_TOKEN" ]]; then
  echo "❌ ERROR: Please export GITLAB_TOKEN before running."
  exit 1
fi

# 1️⃣ Resolve group ID by full path (handles subgroups)
GROUP_API_PATH=$(echo "$GROUP_PATH" | sed 's/\//%2F/g')
GROUP_RESPONSE=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/api/v4/groups/$GROUP_API_PATH")

GROUP_ID=$(echo "$GROUP_RESPONSE" | jq -r '.id')

if [[ "$GROUP_ID" == "null" || -z "$GROUP_ID" ]]; then
  echo "❌ ERROR: Could not resolve group path '$GROUP_PATH'."
  echo "Response: $GROUP_RESPONSE"
  exit 1
fi

echo "✅ Found group '$GROUP_PATH' with ID: $GROUP_ID"

# 2️⃣ Create new project
echo "🚀 Creating new project '$PROJECT_NAME' in '$GROUP_PATH'..."
PROJECT_RESPONSE=$(curl -s --request POST "$GITLAB_URL/api/v4/projects" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --form "name=$PROJECT_NAME" \
  --form "namespace_id=$GROUP_ID" \
  --form "visibility=private")

PROJECT_ID=$(echo "$PROJECT_RESPONSE" | jq -r '.id')

if [[ "$PROJECT_ID" == "null" || -z "$PROJECT_ID" ]]; then
  echo "❌ ERROR: Failed to create project. Response:"
  echo "$PROJECT_RESPONSE"
  exit 1
fi

echo "✅ Project '$PROJECT_NAME' created successfully with ID: $PROJECT_ID"

# 3️⃣ Create branches
echo "🌿 Creating branches..."
for branch in "${BRANCHES[@]}"; do
  curl -s --request POST "$GITLAB_URL/api/v4/projects/$PROJECT_ID/repository/branches" \
    --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    --form "branch=$branch" \
    --form "ref=$DEFAULT_BRANCH" >/dev/null 2>&1 || echo "⚠️ Branch '$branch' already exists or failed."
done

echo "✅ Branches created: ${BRANCHES[*]}"

# 4️⃣ Output repository URL
REPO_URL=$(echo "$PROJECT_RESPONSE" | jq -r '.http_url_to_repo')
echo "🎯 Repository URL: $REPO_URL"


##for dynamically getting foldernames or dbnames in deploy job
deploy:
  stage: deploy
  rules:
    - if: '$CI_PIPELINE_SOURCE == "push"'
      changes:
        - configs/**/app-*.properties
  script:
    - |
      git diff --name-only "$CI_COMMIT_BEFORE_SHA" "$CI_COMMIT_SHA" \
        | awk -F/ '/configs/ {print $2}' \
        | sort -u > dbs.txt

      while read db; do
        echo "Deploying for DB: $db"
        ./deploy.sh "$db"
      done < dbs.txt

