#!/usr/bin/env bash
set -euo pipefail

DEV="app.dev.properties"
TARGETS=("app.uat.properties" "app.prod.properties")

# Ensure dev exists
if [[ ! -f "$DEV" ]]; then
  echo "ERROR: $DEV not found"
  exit 1
fi

for TARGET in "${TARGETS[@]}"; do
  echo "Processing $TARGET"

  # 1️⃣ Create target if missing
  if [[ ! -f "$TARGET" ]]; then
    cp "$DEV" "$TARGET"
    echo "  Created $TARGET from $DEV"
    continue
  fi

  TMP="$(mktemp)"

  # 2️⃣ Sync keys based on DEV
  while IFS='=' read -r key dev_value; do
    # skip empty lines (optional safety)
    [[ -z "$key" ]] && continue

    if grep -q "^${key}=" "$TARGET"; then
      # keep existing target value
      grep "^${key}=" "$TARGET" >> "$TMP"
    else
      # new key → copy from dev
      echo "${key}=${dev_value}" >> "$TMP"
    fi
  done < "$DEV"

  # 3️⃣ Replace target atomically
  mv "$TMP" "$TARGET"
  echo "  Synced $TARGET"
done

echo "✔ UAT & PROD properties are in sync with DEV"
