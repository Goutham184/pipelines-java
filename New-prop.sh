#!/usr/bin/env bash
set -euo pipefail

SRC="app.dev.properties"
TARGETS=("app.uat.properties" "app.prod.properties")

# Ensure source exists
if [[ ! -f "$SRC" ]]; then
  echo "ERROR: $SRC not found"
  exit 1
fi

# Extract valid keys from source
mapfile -t DEV_KEYS < <(
  grep -vE '^\s*$|^\s*#' "$SRC" | cut -d= -f1
)

for TARGET in "${TARGETS[@]}"; do
  echo "Processing $TARGET ..."

  # Create target if not present
  if [[ ! -f "$TARGET" ]]; then
    cp "$SRC" "$TARGET"
    echo "  Created $TARGET"
    continue
  fi

  TMP="$(mktemp)"

  # Build new target file
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

    if grep -q "^${key}=" "$TARGET"; then
      # Keep existing value from target
      grep "^${key}=" "$TARGET" >> "$TMP"
    else
      # New key → copy from dev
      echo "${key}=${value}" >> "$TMP"
    fi
  done < "$SRC"

  # Replace target atomically
  mv "$TMP" "$TARGET"
  echo "  Synced $TARGET"
done

echo "✔ Synchronization complete"
