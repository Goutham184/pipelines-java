#!/bin/bash

DEV_FILE="app.dev.properties"
UAT_FILE="app.uat.properties"
PROD_FILE="app.prod.properties"

# Function to parse properties file into associative array (keys and values)
# Ignores comments (#) and empty lines, handles simple key=value (no spaces around = for simplicity)
declare -A dev_props
parse_props() {
    local file="$1"
    local -n assoc="$2"
    while IFS='=' read -r key value; do
        key=$(echo "$key" | xargs)  # trim leading/trailing spaces
        if [[ -n "$key" && ! "$key" =~ ^[[:space:]]*# && ! "$key" =~ ^[[:space:]]*$ ]]; then
            value="${value//[$'\t
']}"  # trim value, remove newlines/tabs
            assoc["$key"]="$value"
        fi
    done < "$file"
}

# Check if dev file exists
if [[ ! -f "$DEV_FILE" ]]; then
    echo "Error: $DEV_FILE not found."
    exit 1
fi

parse_props "$DEV_FILE" dev_props

# Process UAT
if [[ ! -f "$UAT_FILE" ]]; then
    echo "# Synced from $DEV_FILE on $(date)" > "$UAT_FILE"
    for key in "${!dev_props[@]}"; do
        echo "$key=${dev_props[$key]}" >> "$UAT_FILE"
    done
    echo "Created $UAT_FILE"
else
    # Parse existing UAT
    declare -A uat_props
    parse_props "$UAT_FILE" uat_props
    
    # Remove keys from UAT not in dev
    for key in "${!uat_props[@]}"; do
        if [[ -z "${dev_props[$key]}" ]]; then
            sed -i "/^$key=/d" "$UAT_FILE"  # assumes no spaces before key, adjust if needed
        fi
    done
    
    # Add/Update keys from dev
    for key in "${!dev_props[@]}"; do
        if [[ -z "${uat_props[$key]}" ]]; then
            echo "$key=${dev_props[$key]}" >> "$UAT_FILE"
        else
            sed -i "s/^$key=.*/$key=${dev_props[$key]}/" "$UAT_FILE"
        fi
    done
    echo "Updated $UAT_FILE"
fi

# Process PROD (same logic)
if [[ ! -f "$PROD_FILE" ]]; then
    echo "# Synced from $DEV_FILE on $(date)" > "$PROD_FILE"
    for key in "${!dev_props[@]}"; do
        echo "$key=${dev_props[$key]}" >> "$PROD_FILE"
    done
    echo "Created $PROD_FILE"
else
    declare -A prod_props
    parse_props "$PROD_FILE" prod_props
    
    for key in "${!prod_props[@]}"; do
        if [[ -z "${dev_props[$key]}" ]]; then
            sed -i "/^$key=/d" "$PROD_FILE"
        fi
    done
    
    for key in "${!dev_props[@]}"; do
        if [[ -z "${prod_props[$key]}" ]]; then
            echo "$key=${dev_props[$key]}" >> "$PROD_FILE"
        else
            sed -i "s/^$key=.*/$key=${dev_props[$key]}/" "$PROD_FILE"
        fi
    done
    echo "Updated $PROD_FILE"
fi
