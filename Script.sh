#!/bin/bash

BASE_DOMAIN="example.com"

for ns in $(kubectl get ingress --all-namespaces -o jsonpath='{.items[*].metadata.namespace}' | tr ' ' '\n' | sort -u); do
  for name in $(kubectl get ingress -n "$ns" -o jsonpath='{.items[*].metadata.name}'); do
    host="${name}.${BASE_DOMAIN}"

    echo "Patching ingress $ns/$name with host: $host"

    kubectl patch ingress "$name" -n "$ns" --type='json' -p="[
      {
        \"op\": \"add\",
        \"path\": \"/spec/rules/0/host\",
        \"value\": \"$host\"
      }
    ]"
  done
done
