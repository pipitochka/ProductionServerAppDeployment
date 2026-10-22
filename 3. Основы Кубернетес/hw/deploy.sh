#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLUSTER_NAME="${CLUSTER_NAME:-k8s-lab}"
IMAGE_TAG="${IMAGE_TAG:-v1}"

echo "Building image my-app:${IMAGE_TAG}..."
docker build -t "my-app:${IMAGE_TAG}" "${SCRIPT_DIR}/app"

echo "Loading image into kind cluster ${CLUSTER_NAME}..."
kind load docker-image "my-app:${IMAGE_TAG}" --name "${CLUSTER_NAME}"

echo "Applying manifests..."
kubectl apply -f "${SCRIPT_DIR}/k8s/namespace.yaml"
kubectl apply -f "${SCRIPT_DIR}/k8s/configmap.yaml"
kubectl apply -f "${SCRIPT_DIR}/k8s/secret.yaml"
kubectl apply -f "${SCRIPT_DIR}/k8s/deployment.yaml"
kubectl apply -f "${SCRIPT_DIR}/k8s/service.yaml"

echo "Done. Check status with: kubectl get pods,svc -n k8s-lab"
