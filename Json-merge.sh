#!/usr/bin/env bash
set -euo pipefail

API_JSON="api.json"
TEMPLATE_JSON="template.json"
OUTPUT_JSON="template.json"   # overwrite template.json

# 1️⃣ Convert ALL keys of api.json to lowercase
lower_api=$(jq '
    with_entries(
        .key |= ascii_downcase
    )
' "$API_JSON")

# 2️⃣ Merge lowercase keys into template.json
#     New keys added; existing keys replaced
jq \
    --argjson api "$lower_api" \
    '
        . * $api
    ' "$TEMPLATE_JSON" > tmp.json

# 3️⃣ Save result
mv tmp.json "$OUTPUT_JSON"

echo "✅ template.json successfully updated!"
