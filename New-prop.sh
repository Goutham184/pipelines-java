#!/usr/bin/env bash
set -euo pipefail

# ---------------- CONFIG ----------------
SOURCE_DIR="/opt/config/source"   # where *.dev.properties live
TARGET_DIR="$DB_NAME"             # target directory (external variable)
ENVS=("dev" "qa" "uat" "prod")
# ----------------------------------------

[[ -d "$SOURCE_DIR" ]] || { echo "ERROR: SOURCE_DIR not found: $SOURCE_DIR"; exit 1; }
[[ -n "${TARGET_DIR:-}" ]] || { echo "ERROR: DB_NAME is not set"; exit 1; }

mkdir -p "$TARGET_DIR"

shopt -s nullglob
DEV_FILES=("$SOURCE_DIR"/*.dev.properties)

[[ ${#DEV_FILES[@]} -gt 0 ]] || {
  echo "ERROR: No *.dev.properties files found in $SOURCE_DIR"
  exit 1
}

for SOURCE_FILE in "${DEV_FILES[@]}"; do
  BASENAME="$(basename "$SOURCE_FILE")"
  PREFIX="${BASENAME%.dev.properties}"

  echo "Processing source: $BASENAME"

  # -------- VALIDATE DEV FILE --------
  awk '
    /^[[:space:]]*$/ {
      print "ERROR: Empty line in " FILENAME
      exit 1
    }
    /^[[:space:]]*#/ { next }
    !/^[^=[:space:]]+=[[:print:]]*$/ {
      print "ERROR: Invalid key=value -> " $0
      exit 1
    }
  ' "$SOURCE_FILE"

  # -------- SYNC ALL ENVS --------
  for ENV in "${ENVS[@]}"; do
    TARGET="$TARGET_DIR/${PREFIX}.${ENV}.properties"
    echo "  → $TARGET"

    # Create if missing
    if [[ ! -f "$TARGET" ]]; then
      awk '!/^[[:space:]]*#/' "$SOURCE_FILE" > "$TARGET"
      echo "    Created"
      continue
    fi

    TMP="$(mktemp)"

    awk -F= '
      NR==FNR {
        if ($0 !~ /^[[:space:]]*#/) {
          dev[$1]=$0
          order[++n]=$1
        }
        next
      }
      {
        target[$1]=$0
      }
      END {
        for (i=1; i<=n; i++) {
          k=order[i]
          if (k in target)
            print target[k]
          else {
            print dev[k]
            print "    + Added:", k > "/dev/stderr"
          }
        }
        for (k in target) {
          if (!(k in dev))
            print "    - Removed:", k > "/dev/stderr"
        }
      }
    ' "$SOURCE_FILE" "$TARGET" > "$TMP"

    mv "$TMP" "$TARGET"
    echo "    Synced"
  done
done

echo "✔ All dev property files processed successfully"
