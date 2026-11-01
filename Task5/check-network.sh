#!/usr/bin/env bash
set -uo pipefail

NS="${NS:-default}"
ROLES=(front-end back-end-api admin-front-end admin-back-end-api)

for from in "${ROLES[@]}"; do
  for to in "${ROLES[@]}"; do
    [ "$from" = "$to" ] && continue
    if kubectl -n "$NS" run "check-$RANDOM" --rm -i --restart=Never --quiet \
         --image=alpine --labels="role=$from" \
         -- wget -qO- --timeout=2 "http://$to-app" >/dev/null 2>&1; then
      result="ALLOWED"
    else
      result="denied"
    fi
    printf '%-20s -> %-20s %s\n' "$from" "$to" "$result"
  done
done
