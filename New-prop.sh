awk -F= -v ENV="$ENV" '
  NR==FNR {
    if ($0 !~ /^[[:space:]]*#/) {
      dev[$1]=$2
      order[++n]=$1
    }
    next
  }

  {
    lines[NR]=$0
    keys[NR]=$1
    values[NR]=$2

    # detect TODO comment
    if ($0 ~ /^# TODO: Change this property as per/) {
      todo_line[NR]=1
    }

    # detect existing key=#value
    if ($1 && $2 ~ /^#/) {
      commented[$1]=1
    }

    target[$1]=$2
    last_line=NR
  }

  END {
    for (i=1; i<=n; i++) {
      k=order[i]

      # -------- unchanged --------
      if (k in target && target[k] == dev[k]) {
        print k "=" target[k]
        continue
      }

      # -------- already commented (idempotent) --------
      if (k in commented) {
        print k "=#" dev[k]
        continue
      }

      # -------- added or modified --------
      print "# TODO: Change this property as per " toupper(ENV) " environment"
      print k "=#" dev[k]
    }
  }
' "$SOURCE_FILE" "$TARGET" > "$TMP"
