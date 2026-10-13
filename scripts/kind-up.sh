#!/usr/bin/env bash
# =============================================================================
# kind-up.sh — creates the local registry (localhost:5001) + kind cluster "mlops",
# preloads offline images and (optionally) installs Traefik ingress.
# Usage: ./scripts/kind-up.sh            # session 11: cluster + registry
#        ./scripts/kind-up.sh --ingress  # session 12: also install Traefik
#        ./scripts/kind-up.sh --monitoring  # session 13: also install Prometheus/Grafana
# Based on https://kind.sigs.k8s.io/docs/user/local-registry/
# =============================================================================
set -euo pipefail
L="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=/dev/null
source "$L/versions.env"
REG=kind-registry; CLUSTER=mlops

# 1. Local registry
if [ "$(docker inspect -f '{{.State.Running}}' $REG 2>/dev/null || true)" != true ]; then
  docker run -d --restart=always -p "127.0.0.1:${PORT_REGISTRY}:5000" --network bridge --name $REG "$REGISTRY_IMAGE"
fi

# 2. Cluster
if ! kind get clusters 2>/dev/null | grep -qx $CLUSTER; then
  kind create cluster --name $CLUSTER --image "$KIND_NODE_IMAGE" --config "$L/k8s/kind-config.yaml" --wait 120s
fi

# 3. Map localhost:5001 inside the nodes to the registry container
for NODE in $(kind get nodes --name $CLUSTER); do
  docker exec "$NODE" mkdir -p "/etc/containerd/certs.d/localhost:${PORT_REGISTRY}"
  echo "[host.\"http://${REG}:5000\"]" | docker exec -i "$NODE" cp /dev/stdin "/etc/containerd/certs.d/localhost:${PORT_REGISTRY}/hosts.toml"
done
[ "$(docker inspect -f='{{json .NetworkSettings.Networks.kind}}' $REG)" = null ] && docker network connect kind $REG
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata: {name: local-registry-hosting, namespace: kube-public}
data:
  localRegistryHosting.v1: |
    host: "localhost:${PORT_REGISTRY}"
EOF

# 4. Offline images for cluster add-ons (no internet in class)
[ -f "$L/images/kind-preload.tar.gz" ] && { gunzip -c "$L/images/kind-preload.tar.gz" > /tmp/kind-preload.tar; kind load image-archive /tmp/kind-preload.tar --name $CLUSTER; rm -f /tmp/kind-preload.tar; }

# 5. Optional add-ons
for ARG in "$@"; do case "$ARG" in
  --ingress)
    helm upgrade --install traefik "$L/charts/traefik-${TRAEFIK_CHART_VERSION}.tgz" \
      -n traefik --create-namespace -f "$L/k8s/traefik-values.yaml" --wait ;;
  --monitoring)
    helm upgrade --install monitoring "$L/charts/kube-prometheus-stack-${KUBE_PROM_STACK_CHART_VERSION}.tgz" \
      -n monitoring --create-namespace -f "$L/k8s/monitoring-values.yaml" --wait --timeout 10m ;;
esac; done

kubectl get nodes -o wide
echo "Cluster '$CLUSTER' ready. Registry: localhost:${PORT_REGISTRY}  Ingress: http://localhost:${PORT_INGRESS_HTTP}"
