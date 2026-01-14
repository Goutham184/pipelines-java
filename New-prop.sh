#!/usr/bin/env bash
set -euo pipefail

# ---- CONFIG ----
ENVS=(uat prod)
# ----------------

fail() {
  echo "❌ $1"
  exit 1
}

shopt -s nullglob

DEV_FILES=( *.dev.properties )
[[ ${#DEV_FILES[@]} -gt 0 ]] || fail "No *.dev.properties files found"

echo "🌍 Environments: ${ENVS[*]}"

for DEV in "${DEV_FILES[@]}"; do
  echo
  echo "🔍 Validating $DEV"

  #### DEV VALIDATION ####
  awk '
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
    pos = index($0, "=")
    if (pos == 1) {
      print "Empty key at line " NR
      exit 1
    }
    key = substr($0, 1, pos - 1)
    if (index(key, "=")) {
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
  ' "$DEV" || fail "Validation failed for $DEV"

  echo "✅ $DEV is valid"

  for ENV in "${ENVS[@]}"; do
    TARGET="${DEV/.dev./.$ENV.}"

    echo
    echo "🔄 Syncing $DEV → $TARGET"

    #### CREATE TARGET IF MISSING ####
    if [[ ! -f "$TARGET" ]]; then
      awk '!/^[#;]/ {print}' "$DEV" > "$TARGET"
      echo "✔ Created $TARGET"
      continue
    fi

    TMP="$(mktemp)"

    #### SYNC ####
    awk '
    NR==FNR {
      if ($0 ~ /^[#;]/) next
      pos = index($0, "=")
      k = substr($0, 1, pos - 1)
      v = substr($0, pos + 1)
      dev[k] = v
      order[++n] = k
      next
    }
    /^[#;]/ { next }
    {
      pos = index($0, "=")
      k = substr($0, 1, pos - 1)
      v = substr($0, pos + 1)
      target[k] = v
    }
    END {
      for (i = 1; i <= n; i++) {
        k = order[i]
        if (k in target) {
          print k "=" target[k]
          kept[k] = 1
        } else {
          print k "=" dev[k]
          added[k] = 1
        }
      }

      for (k in target)
        if (!(k in dev))
          removed[k] = 1

      print "" > "/dev/stderr"
      for (k in added)   print "➕ Added   : " k > "/dev/stderr"
      for (k in removed) print "➖ Removed : " k > "/dev/stderr"
      for (k in kept)    print "↺ Retained: " k > "/dev/stderr"
    }
    ' "$DEV" "$TARGET" > "$TMP"

    mv "$TMP" "$TARGET"
    echo "✔ Updated $TARGET"
  done
done

echo
echo "🎉 All *.dev.properties synced to environments: ${ENVS[*]}"
