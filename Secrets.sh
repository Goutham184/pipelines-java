#!/usr/bin/env bash
set -euo pipefail

SOURCE_KV="dev-keyvault-name"
TARGET_KV="bcm-keyvault-name"
SRC_PREFIX="dev-"
TGT_PREFIX="bcm-"

echo "Fetching secrets from $SOURCE_KV..."

az keyvault secret list \
  --vault-name "$SOURCE_KV" \
  --query "[].name" \
  -o tsv | while read -r SECRET_NAME; do

    # ✅ Bash prefix check (reliable)
    if [[ ! "$SECRET_NAME" == ${SRC_PREFIX}* ]]; then
      continue
    fi

    echo "Processing secret: $SECRET_NAME"

    SECRET_VALUE=$(az keyvault secret show \
      --vault-name "$SOURCE_KV" \
      --name "$SECRET_NAME" \
      --query value \
      -o tsv)

    NEW_SECRET_NAME="${SECRET_NAME/#$SRC_PREFIX/$TGT_PREFIX}"

    echo "Creating secret: $NEW_SECRET_NAME"

    az keyvault secret set \
      --vault-name "$TARGET_KV" \
      --name "$NEW_SECRET_NAME" \
      --value "$SECRET_VALUE" \
      >/dev/null

done

echo "✅ Only dev-* secrets migrated successfully"
