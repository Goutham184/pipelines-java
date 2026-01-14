#!/usr/bin/env bash
set -euo pipefail

# ---------------- CONFIG ----------------
SOURCE_DIR="/opt/config/source"     # where *.dev.properties live
TARGET_DIR="$DB_NAME"               # target directory
ENVS=("qa" "uat" "prod")
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

  # -------- COPY DEV AS-IS --------
  DEV_TARGET="$TARGET_DIR/${PREFIX}.dev.properties"
  cp "$SOURCE_FILE" "$DEV_TARGET"
  echo "  → DEV copied as-is"

  # -------- DEV VALIDATION --------
  awk -F= '
    /^[[:space:]]*$/ {
      print "ERROR: Empty line found in " FILENAME
      exit 1
    }
    /^[[:space:]]*#/ { next }
    {
      if ($1 ~ /=/) {
        print "ERROR: Invalid key containing = -> " $1
        exit 1
      }
      if (++seen[$1] > 1) {
        print "ERROR: Duplicate key -> " $1
        exit 1
      }
    }
  ' "$SOURCE_FILE"

  echo "  ✓ DEV validation passed"

  # -------- SYNC QA / UAT / PROD --------
  for ENV in "${ENVS[@]}"; do
    TARGET="$TARGET_DIR/${PREFIX}.${ENV}.properties"
    echo "  → Syncing $TARGET"

    # -------- FIRST TIME CREATION --------
    if [[ ! -f "$TARGET" ]]; then
      awk -F= -v ENV="$ENV" '
        /^[[:space:]]*#/ { next }
        {
          print "# TODO: Update value as per " ENV " environment"
          sub(/=.*/, "=#" $2, $0)
          print
        }
      ' "$SOURCE_FILE" > "$TARGET"
      echo "    Created with TODO comments"
      continue
    fi

    TMP="$(mktemp)"

    awk -F= -v ENV="$ENV" '
      NR==FNR {
        if ($0 !~ /^[[:space:]]*#/) {
          dev[$1]=$0
          devval[$1]=$2
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

          # EXISTING KEY → KEEP AS-IS
          if (k in target) {
            print target[k]
          }
          # NEW KEY → ADD TODO + COMMENT VALUE
          else {
            print "# TODO: Update value as per " ENV " environment"
            sub(/=.*/, "=#" devval[k], dev[k])
            print dev[k]
            print "    + Added:", k > "/dev/stderr"
          }
        }

        # REMOVED KEYS
        for (k in target) {
          if (!(k in dev)) {
            print "    - Removed:", k > "/dev/stderr"
          }
        }
      }
    ' "$SOURCE_FILE" "$TARGET" > "$TMP"

    mv "$TMP" "$TARGET"
    echo "    Synced"
  done
done

echo "✔ DEV copied as-is; QA/UAT/PROD synchronized with TODO workflow"
