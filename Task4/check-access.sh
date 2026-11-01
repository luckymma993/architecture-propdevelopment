#!/usr/bin/env bash
set -uo pipefail

check() {
  local user="$1" group="$2" ns="$3"; shift 3
  printf '%-11s %-20s %-8s %-40s ' "$user" "$group" "${ns:-*}" "$*"
  if [ -n "$ns" ]; then
    kubectl auth can-i "$@" -n "$ns" --as="$user" --as-group="$group"
  else
    kubectl auth can-i "$@" --all-namespaces --as="$user" --as-group="$group"
  fi
}

check ivanov     security-admins    ""      get secrets
check ivanov     security-admins    ""      create secrets
check ivanov     security-admins    ""      delete namespaces
check petrov     devops-platform    ""      create namespaces
check petrov     devops-platform    ""      create networkpolicies
check petrov     devops-platform    ""      get secrets
check sidorova   business-analysts  ""      list pods
check sidorova   business-analysts  ""      get secrets
check sidorova   business-analysts  sales   delete pods
check orlov      ops-engineers      housing create pods --subresource=exec
check orlov      ops-engineers      housing patch deployments/scale
check orlov      ops-engineers      housing create deployments
check smirnov    sales-developers   sales   create deployments
check smirnov    sales-developers   housing create deployments
check smirnov    sales-developers   sales   get secrets
check kuznetsova housing-developers housing create services
check kuznetsova housing-developers finance list pods
