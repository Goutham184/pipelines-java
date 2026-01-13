#!/usr/bin/env bash
set -euo pipefail

SRC="app.dev.properties"
TARGETS=("app.uat.properties" "app.prod.properties")

### -------------------------------
### 1️⃣ Validate DEV file
### -------------------------------
if [[ ! -f "$SRC" ]]; then
  echo "ERROR: $SRC not found"
  exit 1
fi

# No empty or comment lines
if grep -nE '^\s*$|^\s*#' "$SRC"; then
  echo "ERROR: Empty lines or comments not allowed in $SRC"
  exit 1
fi

# Strict key=value
if grep -nEv '^[^=[:space:]]+=[^[:space:]]+$' "$SRC"; then
  echo "ERROR: Invalid key=value format in $SRC"
  exit 1
fi

# Duplicate keys
if cut -d= -f1 "$SRC" | sort | uniq -d | grep -q .; then
  echo "ERROR: Duplicate keys found in $SRC"
  cut -d= -f1 "$SRC" | sort | uniq -d
  exit 1
fi

echo "✔ DEV validation passed"

### -------------------------------
### 2️⃣ Sync targets
### -------------------------------
for TARGET in "${TARGETS[@]}"; do
  echo "Processing $TARGET"

  # Create if missing
  if [[ ! -f "$TARGET" ]]; then
    cp "$SRC" "$TARGET"
    echo "  Created $TARGET"
    continue
  fi

  TMP="$(mktemp)"

  while IFS='=' read -r key dev_value; do
    if grep -q "^${key}=" "$TARGET"; then
      # Keep existing target value
      grep "^${key}=" "$TARGET" >> "$TMP"
    else
      # New key → copy from dev
      echo "${key}=${dev_value}" >> "$TMP"
    fi
  done < "$SRC"

  mv "$TMP" "$TARGET"
  echo "  Synced $TARGET"
done

echo "✔ Sync complete"
