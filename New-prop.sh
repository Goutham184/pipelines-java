awk -F= -v ENV="$ENV" '
  # ---------- Read DEV ----------
  NR==FNR {
    if ($0 !~ /^[[:space:]]*#/) {
      dev[$1]=$2
      order[++n]=$1
    }
    next
  }

  # ---------- Read TARGET ----------
  {
    line[NR]=$0
    key=$1
    val=$2

    if ($0 ~ /^# TODO: Change this property as per/) {
      todo_seen=1
      next
    }

    if (key != "") {
      target[key]=val
      rawline[key]=$0

      # detect commented value (key=#value)
      if (val ~ /^#/) {
        commented[key]=1
        frozen[key]=val   # preserve original commented value
      }
    }
  }

  END {
    for (i=1; i<=n; i++) {
      k=order[i]

      # ---------- Case 1: already commented (DO NOT TOUCH) ----------
      if (k in commented) {
        print "# TODO: Change this property as per " toupper(ENV) " environment"
        print k "=" frozen[k]
        continue
      }

      # ---------- Case 2: exists but value differs ----------
      if (k in target && target[k] != dev[k]) {
        print "# TODO: Change this property as per " toupper(ENV) " environment"
        print k "=#" dev[k]
        continue
      }

      # ---------- Case 3: new key ----------
      if (!(k in target)) {
        print "# TODO: Change this property as per " toupper(ENV) " environment"
        print k "=#" dev[k]
        continue
      }

      # ---------- Case 4: unchanged ----------
      print k "=" target[k]
    }
  }
' "$SOURCE_FILE" "$TARGET" > "$TMP"
