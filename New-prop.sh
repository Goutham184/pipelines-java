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
  echo
