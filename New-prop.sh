#!/bin/bash
set -euo pipefail

fail() {
  echo "[ERROR] $1"
  exit 1
}

log() {
  echo "[SYNC] $1"
}

validate_dev_file() {
  local file="$1"

  log "Validating $file"

  # 1. No empty lines
  if grep -n '^$' "$file" >/dev/null; then
    fail "$file contains empty lines"
  fi

  # 2. No commented lines
  if grep -n '^[[:space:]]*#' "$file" >/dev/null; then
    fail "$file contains commented lines"
  fi

  # 3. No leading/trailing spaces
  if grep -n '^[[:space:]]\|[[:space:]]$' "$file" >/dev/null; then
    fail "$file contains leading or trailing spaces"
  fi

  # 4. Must be strict key=value
  if grep -n -v '^[^=[:space:]]\+=[^[:space:]]\+$' "$file" >/dev/null; then
    fail "$file has invalid key=value format"
  fi

  # 5. Keys must not contain '='
  if awk -F= '{ if ($1 ~ /=/) exit 1 }' "$file"; then :; else
    fail "$file has invalid key containing '='"
  fi

  # 6. No duplicate keys
  if awk -F= '{print $1}' "$file" | sort | uniq -d | grep . >/dev/null; then
    fail "$file contains duplicate keys"
  fi

  # 7. No multiline values
  if awk -F= 'NF != 2 { exit 1 }' "$file"; then :; else
    fail "$file contains multiline or malformed values"
  fi

  log "$file validation PASSED"
}

# ---------------- MAIN ----------------

for DEV_FILE in *.dev.properties; do
  [[ -e "$DEV_FILE" ]] || continue

  validate_dev_file "$DEV_FILE"

  BASE_NAME="${DEV_FILE%.dev.properties}"

  for ENV in uat prod; do
    TARGET_FILE="${BASE_NAME}.${ENV}.properties"

    # First run → copy
    if [[ ! -f "$TARGET_FILE" ]]; then
      log "Creating $TARGET_FILE"
      cp "$DEV_FILE" "$TARGET_FILE"
      continue
    fi

    log "Syncing keys with $TARGET_FILE"

    # Ensure newline at EOF
    [[ "$(tail -c1 "$TARGET_FILE")" == $'\n' ]] || echo >> "$TARGET_FILE"

    # Extract DEV keys
    DEV_KEYS=$(cut -d= -f1 "$DEV_FILE")

    # ADD missing keys
    while IFS= read -r line; do
      KEY="${line%%=*}"

      if ! grep -q "^${KEY}=" "$TARGET_FILE"; then
        printf '%s\n' "$line" >> "$TARGET_FILE"
        log "➕ Added $KEY to $TARGET_FILE"
      fi
    done < "$DEV_FILE"

    # REMOVE extra keys
    while IFS= read -r tline; do
      TKEY="${tline%%=*}"

      if ! grep -qx "$TKEY" <<< "$DEV_KEYS"; then
        sed -i.bak "/^${TKEY}=/d" "$TARGET_FILE"
        log "➖ Removed $TKEY from $TARGET_FILE"
      fi
    done < "$TARGET_FILE"

    rm -f "${TARGET_FILE}.bak"
  done
done

log "SYNC COMPLETED SUCCESSFULLY"
