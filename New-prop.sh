#!/usr/bin/env bash
set -e

DEV="app.dev.properties"
TARGETS=("app.uat.properties" "app.prod.properties")

for TARGET in "${TARGETS[@]}"; do
  # Create target if missing
  if [[ ! -f "$TARGET" ]]; then
    cp "$DEV" "$TARGET"
    continue
  fi

  # 1️⃣ Remove keys not present in DEV
  grep -F -f <(cut -d= -f1 "$DEV" | sed 's/$/=/' ) "$TARGET" > "${TARGET}.tmp"

  # 2️⃣ Add keys missing in TARGET
  grep -F -v -f <(cut -d= -f1 "${TARGET}.tmp" | sed 's/$/=/' ) "$DEV" >> "${TARGET}.tmp"

  mv "${TARGET}.tmp" "$TARGET"
done
