#!/usr/bin/env bash
set -euo pipefail

DEV="app.dev.properties"
TARGETS=("app.uat.properties" "app.prod.properties")

if [[ ! -f "$DEV" ]]; then
  echo "ERROR: $DEV not found"
  exit 1
fi

for TARGET in "${TARGETS[@]}"; do
  echo "Processing $TARGET"

  # Create target if missing
  if [[ ! -f "$TARGET" ]]; then
    cp "$DEV" "$TARGET"
    echo "  Created $TARGET"
    continue
  fi

  TMP="$(mktemp)"

  awk -F= '
    NR==FNR {
      dev[$1]=$2
      order[NR]=$1
      next
    }
    {
      if ($1 in dev) {
        target[$1]=$2
      }
    }
    END {
      for (i=1; i<=length(order); i++) {
        k=order[i]
        if (k in target)
          print k "=" target[k]
        else
          print k "=" dev[k]
      }
    }
  ' "$DEV" "$TARGET" > "$TMP"

  mv "$TMP" "$TARGET"
  echo "  Synced $TARGET"
done

echo "✔ DEV, UAT, PROD are fully synchronized"
