#!/usr/bin/env bash
set -euo pipefail
umask 077

cd "$(dirname "${BASH_SOURCE[0]}")"
MODE="${1:-prod}"
case "$MODE" in
  dev|prod) ;;
  *) echo 'Usage: ./setup.sh [dev|prod]' >&2; exit 1 ;;
esac
NAMESPACE="${NAMESPACE:-keycloak-$MODE}"
RELEASE="${RELEASE:-keycloak}"
if [[ ! "$RELEASE" =~ ^[a-z][a-z0-9-]{0,38}[a-z0-9]$ ]]; then
  echo 'RELEASE must contain 2–40 lowercase letters, digits or hyphens.' >&2
  exit 1
fi
LOCAL_DIR=".local/$NAMESPACE/$RELEASE"
mkdir -p "$LOCAL_DIR"

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
if [[ -z "$(kubectl -n "$NAMESPACE" get secret "$RELEASE-credentials" --ignore-not-found -o name)" ]]; then
  # Retain the file so re-running setup never silently changes the DB password.
  if [[ ! -f "$LOCAL_DIR/credentials.env" ]]; then
    printf 'admin-password=%s\ndatabase-password=%s\n' \
      "$(openssl rand -hex 24)" "$(openssl rand -hex 24)" > "$LOCAL_DIR/credentials.env"
  fi
  kubectl -n "$NAMESPACE" create secret generic "$RELEASE-credentials" \
    --from-env-file="$LOCAL_DIR/credentials.env"
fi

if [[ "$MODE" == prod ]] && [[ -z "$(kubectl -n "$NAMESPACE" get secret "$RELEASE-tls" --ignore-not-found -o name)" ]]; then
  # SANs cover the browser, port-forward and the in-cluster Helm test.
  cat > "$LOCAL_DIR/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = extensions
prompt = no
[dn]
CN = localhost
[extensions]
subjectAltName = DNS:localhost,IP:127.0.0.1,DNS:$RELEASE,DNS:$RELEASE.$NAMESPACE.svc,DNS:$RELEASE.$NAMESPACE.svc.cluster.local
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature,keyEncipherment
extendedKeyUsage = serverAuth
EOF
  openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 365 \
    -config "$LOCAL_DIR/openssl.cnf" \
    -keyout "$LOCAL_DIR/tls.key" -out "$LOCAL_DIR/tls.crt" 2>/dev/null
  kubectl -n "$NAMESPACE" create secret tls "$RELEASE-tls" \
    --cert="$LOCAL_DIR/tls.crt" --key="$LOCAL_DIR/tls.key"
fi

helm upgrade --install "$RELEASE" ./keycloak \
  --namespace "$NAMESPACE" -f "values-$MODE.yaml" --wait --timeout 10m
helm test "$RELEASE" --namespace "$NAMESPACE" --logs --timeout 2m
