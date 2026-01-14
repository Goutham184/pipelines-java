awk -F= -v ENV="$ENV" '
  # -------- READ DEV --------
  NR==FNR {
    if ($0 !~ /^[[:space:]]*#/) {
      dev[$1]=$0
      devval[$1]=$2
      order[++n]=$1
    }
    next
  }

  # -------- READ TARGET (PRESERVE TODOs) --------
  {
    if ($0 ~ /^# TODO: Update value as per/) {
      pending_todo = $0
      next
    }

    if ($0 !~ /^[[:space:]]*#/ && $1 != "") {
      target[$1]=$0
      if (pending_todo != "") {
        todo[$1]=pending_todo
        pending_todo=""
      }
    }
  }

  END {
    for (i=1; i<=n; i++) {
      k = order[i]

      # EXISTING KEY
      if (k in target) {
        if (k in todo)
          print todo[k]
        print target[k]
      }
      # NEW KEY
      else {
        print "# TODO: Update value as per " ENV " environment"
        sub(/=.*/, "=#" devval[k], dev[k])
        print dev[k]
      }
    }
    # Removed keys are naturally dropped
  }
' "$SOURCE_FILE" "$TARGET" > "$TMP"
