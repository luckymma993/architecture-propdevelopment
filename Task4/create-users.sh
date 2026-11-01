#!/usr/bin/env bash
set -euo pipefail

export MSYS_NO_PATHCONV=1

USERS_DIR="${USERS_DIR:-$(dirname "$0")/users}"
CLUSTER="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')"

USERS=(
  "ivanov:security-admins"
  "petrov:devops-platform"
  "sidorova:business-analysts"
  "orlov:ops-engineers"
  "smirnov:sales-developers"
  "kuznetsova:housing-developers"
)

mkdir -p "$USERS_DIR"

for entry in "${USERS[@]}"; do
  user="${entry%%:*}"
  group="${entry##*:}"
  key="$USERS_DIR/$user.key"
  csr="$USERS_DIR/$user.csr"
  crt="$USERS_DIR/$user.crt"

  echo "==> $user ($group)"

  openssl genrsa -out "$key" 2048 2>/dev/null
  openssl req -new -key "$key" -out "$csr" -subj "/CN=$user/O=$group"

  kubectl delete csr "$user" --ignore-not-found >/dev/null
  cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $user
spec:
  request: $(base64 < "$csr" | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 31536000
  usages:
    - client auth
EOF

  kubectl certificate approve "$user"
  for _ in $(seq 1 20); do
    cert="$(kubectl get csr "$user" -o jsonpath='{.status.certificate}')"
    [ -n "$cert" ] && break
    sleep 1
  done
  echo "$cert" | base64 -d > "$crt"

  kubectl config set-credentials "$user" \
    --client-certificate="$crt" --client-key="$key" --embed-certs=true >/dev/null
  kubectl config set-context "$user" --cluster="$CLUSTER" --user="$user" >/dev/null
done

echo "Users created. Switch with: kubectl config use-context <user>"
