#!/usr/bin/env bash
set -euo pipefail

SRC="app.dev.properties"
TARGETS=("app.uat.properties" "app.prod.properties")

### -------------------------------
### 1️⃣ Validate DEV properties
### -------------------------------
if [[ ! -f "$SRC" ]]; then
  echo "ERROR: $SRC not found"
  exit 1
fi

# Empty lines OR comments
if grep -nE '^\s*$|^\s*#' "$SRC"; then
  echo "ERROR: Empty lines or comments are NOT allowed in $SRC"
  exit 1
fi

# Invalid key=value format
if grep -nEv '^[^=[:space:]]+=[^[:space:]].*$' "$SRC"; then
  echo "ERROR: Invalid key=value format in $SRC"
  exit 1
fi

# Duplicate keys
DUP_KEYS=$(cut -d= -f1 "$SRC" | sort | uniq -d)
if [[ -n "$DUP_KEYS" ]]; then
  echo "ERROR: Duplicate keys found in $SRC:"
  echo "$DUP_KEYS"
  exit 1
fi

echo "✔ DEV properties validation passed"

### -------------------------------
### 2️⃣ Load DEV into associative array
### -------------------------------
declare -A DEV_MAP
while IFS='=' read -r key value; do
  DEV_MAP["$key"]="$value"
done < "$SRC"

### -------------------------------
### 3️⃣ Sync TARGET files
### -------------------------------
for TARGET in "${TARGETS[@]}"; do
  echo "Processing $TARGET..."

  # Create if missing
  if [[ ! -f "$TARGET" ]]; then
    cp "$SRC" "$TARGET"
    echo "  Created $TARGET"
    continue
  fi

  declare -A TARGET_MAP
  while IFS='=' read -r key value; do
    TARGET_MAP["$key"]="$value"
  done < "$TARGET"

  TMP="$(mktemp)"

  # Source of truth = DEV order + keys
  for key in "${!DEV_MAP[@]}"; do
    if [[ -n "${TARGET_MAP[$key]+x}" ]]; then
      # Key exists → keep target value
      echo "$key=${TARGET_MAP[$key]}" >> "$TMP"
    else
      # New key → copy from dev
      echo "$key=${DEV_MAP[$key]}" >> "$TMP"
    fi
  done

  mv "$TMP" "$TARGET"
  echo "  Synced $TARGET"

  unset TARGET_MAP
done

echo "✔ All properties synced successfully"
