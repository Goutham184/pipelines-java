#!/bin/bash

DEV_FILE="app.dev.properties"
UAT_FILE="app.uat.properties"
PROD_FILE="app.prod.properties"

# Function to parse properties into assoc array (keys only for checks/updates)
declare -A dev_keys
parse_keys() {
    local file="$1"
    local -n assoc="$2"
    while IFS='=' read -r key _; do
        key=$(echo "$key" | xargs)
        if [[ -n "$key" && ! "$key" =~ ^[[:space:]]*# && ! "$key" =~ ^[[:space:]]*$ ]]; then
            assoc["$key"]=1
        fi
    done < "$file"
}

# Check dev file
if [[ ! -f "$DEV_FILE" ]]; then
    echo "Error: $DEV_FILE not found."
    exit 1
fi

parse_keys "$DEV_FILE" dev_keys

# Process UAT
if [[ ! -f "$UAT_FILE" ]]; then
    cp "$DEV_FILE" "$UAT_FILE"
    echo "Created $UAT_FILE by exact copy of $DEV_FILE"
else
    # Parse UAT keys
    declare -A uat_keys
    parse_keys "$UAT_FILE" uat_keys
    
    # Remove lines for keys not in dev
    for key in "${!uat_keys[@]}"; do
        if [[ -z "${dev_keys[$key]}" ]]; then
            sed -i "/^${key}([[:space:]]*=[[:space:]]*)[[:print:]]*/d" "$UAT_FILE"
        fi
    done
    
    # Add/update keys from dev
    while IFS='=' read -r key value; do
        key=$(echo "$key" | xargs)
        if [[ -n "$key" && ! "$key" =~ ^[[:space:]]*# && ! "$key" =~ ^[[:space:]]*$ ]]; then
            value="${value//[$'\t
']}"
            if [[ -z "${uat_keys[$key]}" ]]; then
                echo "$key=$value" >> "$UAT_FILE"
            else
                sed -i "/^${key}([[:space:]]*=[[:space:]]*)[[:print:]]*/c\\$key=$value" "$UAT_FILE"
            fi
        fi
    done < "$DEV_FILE"
    echo "Updated $UAT_FILE"
fi

# Process PROD identically
if [[ ! -f "$PROD_FILE" ]]; then
    cp "$DEV_FILE" "$PROD_FILE"
    echo "Created $PROD_FILE by exact copy of $DEV_FILE"
else
    declare -A prod_keys
    parse_keys "$PROD_FILE" prod_keys
    
    for key in "${!prod_keys[@]}"; do
        if [[ -z "${dev_keys[$key]}" ]]; then
            sed -i "/^${key}([[:space:]]*=[[:space:]]*)[[:print:]]*/d" "$PROD_FILE"
        fi
    done
    
    while IFS='=' read -r key value; do
        key=$(echo "$key" | xargs)
        if [[ -n "$key" && ! "$key" =~ ^[[:space:]]*# && ! "$key" =~ ^[[:space:]]*$ ]]; then
            value="${value//[$'\t
']}"
            if [[ -z "${prod_keys[$key]}" ]]; then
                echo "$key=$value" >> "$PROD_FILE"
            else
                sed -i "/^${key}([[:space:]]*=[[:space:]]*)[[:print:]]*/c\\$key=$value" "$PROD_FILE"
            fi
        fi
    done < "$DEV_FILE"
    echo "Updated $PROD_FILE"
fi
