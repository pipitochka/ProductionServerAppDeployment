#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "${SCRIPT_DIR}/certs"
cd "${SCRIPT_DIR}/certs"

HOSTNAME="${1:-keycloak.local}"

openssl genrsa -out ca.key 2048
openssl req -x509 -new -nodes -key ca.key -sha256 -days 3650 \
  -out ca.crt -subj "/CN=KeycloakHomeworkCA"

openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr \
  -subj "/CN=${HOSTNAME}/O=IDSA" \
  -addext "subjectAltName=DNS:${HOSTNAME}"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days 365 -sha256 -copy_extensions copy

echo "Certificates generated for ${HOSTNAME}"
echo "Add to /etc/hosts: 127.0.0.1 ${HOSTNAME}"
