#!/usr/bin/env bash
set -euo pipefail

cat <<'EOF' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-viewer-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-viewer
subjects:
  - kind: Group
    name: business-analysts
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: ops-engineers
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: devops-platform
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: security-admins
    apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-configurator-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-configurator
subjects:
  - kind: Group
    name: devops-platform
    apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: secrets-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: secrets-admin
subjects:
  - kind: Group
    name: security-admins
    apiGroup: rbac.authorization.k8s.io
EOF

bind_namespace() {
  local ns="$1" role="$2" group="$3"
  cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $role-$group
  namespace: $ns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: $role
subjects:
  - kind: Group
    name: $group
    apiGroup: rbac.authorization.k8s.io
EOF
}

bind_namespace sales   namespace-developer sales-developers
bind_namespace housing namespace-developer housing-developers
bind_namespace finance namespace-developer finance-developers
bind_namespace data    namespace-developer data-engineers

for ns in sales housing finance data; do
  bind_namespace "$ns" namespace-operator ops-engineers
done

kubectl get clusterrolebindings cluster-viewer-binding cluster-configurator-binding secrets-admin-binding
kubectl get rolebindings -A | grep -E 'namespace-(developer|operator)'
