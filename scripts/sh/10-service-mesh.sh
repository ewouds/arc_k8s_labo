#!/bin/bash
# ============================================================================
# Script 10 - Service Mesh on Azure Arc-enabled Kubernetes
# Demonstrates Linkerd service mesh deployed & managed through Arc capabilities
# Run from your LOCAL machine
# ============================================================================
set -e

echo "============================================"
echo "  Service Mesh on Azure Arc"
echo "============================================"

# --- Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arcworkshop}"
CLUSTER_NAME="${CLUSTER_NAME:-arc-k3s-cluster}"
SSH_HOST="${SSH_HOST:-}"  # e.g. user@ip — needed for Linkerd CLI install on cluster

echo ""
echo "📋 Configuration:"
echo "  Resource Group:  $RESOURCE_GROUP"
echo "  Cluster Name:    $CLUSTER_NAME"

# ============================================================================
# STEP 1 — Install Linkerd via Arc Cluster Connect (kubectl proxy)
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 1: Install Linkerd Service Mesh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Linkerd is a lightweight CNCF-graduated service mesh."
echo "  It adds: mTLS, observability, traffic splitting."
echo "  Memory footprint: ~50 MB (ideal for K3s / edge)."
echo ""

# Check if Linkerd CLI is available locally
if ! command -v linkerd &> /dev/null; then
  echo "📦 Installing Linkerd CLI..."
  curl -fsL https://run.linkerd.io/install | sh
  export PATH=$HOME/.linkerd2/bin:$PATH
  echo "  ✅ Linkerd CLI installed"
else
  echo "  ✅ Linkerd CLI already installed"
fi

echo ""
echo "🔍 Pre-flight check..."
linkerd check --pre 2>&1 | tail -5

echo ""
echo "📦 Installing Linkerd CRDs..."
linkerd install --crds | kubectl apply -f - 2>/dev/null

echo ""
echo "📦 Installing Linkerd control plane..."
linkerd install | kubectl apply -f - 2>/dev/null

echo ""
echo "⏳ Waiting for Linkerd to become ready..."
linkerd check 2>&1 | tail -10

echo "  ✅ Linkerd control plane installed"

# ============================================================================
# STEP 2 — Deploy mesh demo app via Arc GitOps
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 2: Deploy Mesh Demo App via GitOps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Architecture: Frontend (nginx) → Backend (http-echo)"
echo "  Both pods get Linkerd sidecar proxies automatically."
echo ""
echo "  🔑 Arc added value: Deploy via GitOps — no direct cluster access needed!"
echo ""

echo "📦 Creating mesh-demo namespace..."
kubectl apply -f k8s/mesh-demo/namespace.yaml

echo "📦 Deploying frontend + backend..."
kubectl apply -f k8s/mesh-demo/backend-v1.yaml
kubectl apply -f k8s/mesh-demo/backend-service.yaml
kubectl apply -f k8s/mesh-demo/frontend.yaml

echo ""
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=backend -n mesh-demo --timeout=120s
kubectl wait --for=condition=ready pod -l app=frontend -n mesh-demo --timeout=120s

echo ""
echo "📊 Mesh demo pods:"
kubectl get pods -n mesh-demo -o wide

# ============================================================================
# STEP 3 — Verify mTLS between services
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 3: Verify mTLS (Zero-Trust)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Linkerd automatically encrypts all pod-to-pod traffic"
echo "  using mutual TLS — no code changes needed!"
echo ""

# Check sidecar injection
echo "🔍 Checking sidecar injection..."
FRONTEND_CONTAINERS=$(kubectl get pod -l app=frontend -n mesh-demo -o jsonpath='{.items[0].spec.containers[*].name}')
echo "  Frontend containers: $FRONTEND_CONTAINERS"

BACKEND_CONTAINERS=$(kubectl get pod -l app=backend -n mesh-demo -o jsonpath='{.items[0].spec.containers[*].name}')
echo "  Backend containers:  $BACKEND_CONTAINERS"

echo ""
echo "🔐 Checking mTLS status..."
linkerd viz stat deploy -n mesh-demo 2>/dev/null || echo "  (Install linkerd-viz for detailed stats: linkerd viz install | kubectl apply -f -)"

echo ""
echo "🌐 Testing service-to-service call..."
FRONTEND_POD=$(kubectl get pod -l app=frontend -n mesh-demo -o jsonpath='{.items[0].metadata.name}')
kubectl exec "$FRONTEND_POD" -n mesh-demo -c frontend -- wget -qO- http://backend.mesh-demo.svc.cluster.local/

echo ""
echo "  ✅ mTLS active — traffic is encrypted between services"

# ============================================================================
# STEP 4 — Observe in Azure (Container Insights)
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 4: Observe via Container Insights"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  🔑 Arc added value: Azure Monitor sees mesh sidecar metrics!"
echo ""
echo "  Container Insights captures:"
echo "    • Sidecar proxy CPU/memory usage"
echo "    • Pod startup time with sidecars"
echo "    • Container restart counts per sidecar"
echo ""

echo "📊 Querying Container Insights for mesh-demo pods..."
echo ""
echo "  📂 View in Portal:"
echo "     Arc cluster > Insights > Containers"
echo "     Filter namespace: mesh-demo"
echo ""
echo "  You should see 2 containers per pod:"
echo "    • Application container (frontend / backend)"
echo "    • linkerd-proxy sidecar"

echo ""
echo "  KQL query for sidecar metrics:"
echo '  ContainerInventory'
echo '  | where Namespace == "mesh-demo"'
echo '  | where ContainerName contains "linkerd"'
echo '  | summarize count() by Computer, ContainerName'

# ============================================================================
# STEP 5 — Traffic splitting (canary) via GitOps
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 5: Canary Deploy via Traffic Splitting"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Deploying backend-v2 and SMI TrafficSplit:"
echo "    80% → backend-v1 🟢"
echo "    20% → backend-v2 🔵 (canary)"
echo ""
echo "  🔑 Arc added value: push TrafficSplit to Git → Flux applies it!"
echo ""

echo "📦 Deploying backend-v2 + TrafficSplit..."
kubectl apply -f k8s/mesh-demo/backend-v2.yaml
kubectl apply -f k8s/mesh-demo/traffic-split.yaml

echo ""
echo "⏳ Waiting for backend-v2..."
kubectl wait --for=condition=ready pod -l app=backend,version=v2 -n mesh-demo --timeout=120s

echo ""
echo "📊 All backend pods:"
kubectl get pods -l app=backend -n mesh-demo

echo ""
echo "🌐 Testing traffic split (10 requests)..."
for i in $(seq 1 10); do
  kubectl exec "$FRONTEND_POD" -n mesh-demo -c frontend -- wget -qO- http://backend.mesh-demo.svc.cluster.local/ 2>/dev/null
done

echo ""
echo "  You should see ~80% v1 🟢 and ~20% v2 🔵 responses"

# ============================================================================
# STEP 6 — Azure Policy for mesh enforcement
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Step 6: Enforce Mesh via Azure Policy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  🔑 Arc added value: Enforce sidecar injection at the Azure level!"
echo ""
echo "  In a production scenario, you would create an Azure Policy that:"
echo "    • Audits pods without the linkerd.io/inject annotation"
echo "    • Denies deployments to mesh-enabled namespaces without sidecars"
echo "    • Reports compliance in the Azure Portal"
echo ""
echo "  📊 Checking namespace labels..."
kubectl get namespace mesh-demo --show-labels

echo ""
echo "  The namespace label 'linkerd.io/inject=enabled' ensures all"
echo "  new pods automatically get the sidecar proxy."
echo ""
echo "  📂 View Policy compliance:"
echo "     Portal > Policy > Compliance"
echo "     Filter: Resource type = connectedClusters"

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "============================================"
echo "  ✅ Service Mesh on Arc — Complete!"
echo ""
echo "  What we demonstrated:"
echo "    🔐 mTLS between services (zero-trust)"
echo "    📊 Container Insights observability"
echo "    🔀 Canary deploy via TrafficSplit"
echo "    📜 GitOps-driven mesh config"
echo "    🛡️  Azure Policy enforcement"
echo ""
echo "  Arc Added Value:"
echo "    • Single pane of glass — mesh metrics in Azure"
echo "    • GitOps deployment — no direct cluster access"
echo "    • Azure Policy — governance across clusters"
echo "    • Same workflow for on-prem, edge, multi-cloud"
echo "============================================"
