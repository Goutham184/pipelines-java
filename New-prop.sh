#!/usr/bin/env bash
set -e

DEV="app.dev.properties"
TARGETS=("app.uat.properties" "app.prod.properties")

for TARGET in "${TARGETS[@]}"; do
  # Create if missing
  [[ ! -f "$TARGET" ]] && cp "$DEV" "$TARGET" && continue

  awk -F= '
    FNR==NR {                     # read DEV
      dev[$1]=$2
      order[++n]=$1
      next
    }
    $1 in dev {                   # read TARGET
      tgt[$1]=$2
    }
    END {
      for (i=1; i<=n; i++) {
        k=order[i]
        print k "=" (k in tgt ? tgt[k] : dev[k])
      }
    }
  ' "$DEV" "$TARGET" > "$TARGET.tmp"

  mv "$TARGET.tmp" "$TARGET"
done
