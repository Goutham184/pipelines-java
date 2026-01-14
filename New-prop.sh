#!/usr/bin/env bash
set -euo pipefail

DEV="app.dev.properties"
TARGETS=("app.uat.properties" "app.prod.properties")

fail() {
  echo "❌ $1"
  exit 1
}

[[ -f "$DEV" ]] || fail "$DEV not found"

echo "🔍 Validating $DEV"

awk -F= '
/^[[:space:]]*$/ {
  print "Empty line at line " NR
  exit 1
}
/^[#;]/ { next }
/[[:space:]]/ {
  print "Spaces are not allowed at line " NR ": " $0
  exit 1
}
/=/ {
  if (NF != 2) {
    print "Invalid key=value at line " NR
    exit 1
  }
  key=$1
  if (index(key,"=")) {
    print "Invalid key at line " NR
    exit 1
  }
  if (seen[key]++) {
    print "Duplicate key: " key
    exit 1
  }
  next
}
{
  print "Invalid line at " NR ": " $0
  exit 1
}
' "$DEV" || fail "DEV validation failed"

echo "✅ DEV is valid"

for TARGET in "${TARGETS[@]}"; do
  echo
  echo "🔄 Syncing $TARGET"

  [[ -f "$TARGET" ]] || {
    awk -F= '!/^[#;]/ {print}' "$DEV" > "$TARGET"
    echo "✔ Created $TARGET"
    continue
  }

  TMP="$(mktemp)"

  awk -F= '
  NR==FNR {
    if ($0 ~ /^[#;]/) next
    dev[$1]=$2
    order[++n]=$1
    next
  }
  /^[#;]/ { next }
  {
    target[$1]=$2
  }
  END {
    for (i=1; i<=n; i++) {
      k=order[i]
      if (k in target) {
        print k "=" target[k]
        kept[k]=1
      } else {
        print k "=" dev[k]
        added[k]=1
      }
    }

    for (k in target)
      if (!(k in dev))
        removed[k]=1

    print "" > "/dev/stderr"
    for (k in added)   print "➕ Added   : " k > "/dev/stderr"
    for (k in removed) print "➖ Removed : " k > "/dev/stderr"
    for (k in kept)    print "↺ Retained: " k > "/dev/stderr"
  }
  ' "$DEV" "$TARGET" > "$TMP"

  mv "$TMP" "$TARGET"
  echo "✔ Updated $TARGET"
done

echo
echo "🎉 DEV → UAT / PROD synchronization complete"
