#!/bin/bash
# ============================================================================
# Script 04 - Deploy Container via Azure Arc Cluster Connect
# Run this from your LOCAL machine (not the VM)
#
# This script demonstrates deploying a workload to an Arc-connected cluster
# using Cluster Connect (az connectedk8s proxy).
# No VPN, no SSH, no direct network access needed — that's the power of Arc.
# ============================================================================
set -e

echo "============================================"
echo "  Deploy Container via Azure Arc"
echo "============================================"

# --- Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arcworkshop}"
CLUSTER_NAME="${CLUSTER_NAME:-arc-k3s-cluster}"

echo ""
echo "📋 Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Cluster Name:   $CLUSTER_NAME"

# ============================================================================
# Cluster Connect (az connectedk8s proxy)
#   Opens a tunnel via Azure Arc to the cluster — no direct network access
#   needed. All traffic flows through Azure as a reverse proxy.
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Cluster Connect — deploying via Azure Arc proxy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "🔌 Checking Cluster Connect..."

# Check if a proxy is already running and kubectl works
PROXY_PID=""
if kubectl get nodes &>/dev/null; then
  echo "  ✅ Existing proxy detected — reusing connection"
else
  echo "  Starting Cluster Connect proxy..."
  az connectedk8s proxy -n "$CLUSTER_NAME" -g "$RESOURCE_GROUP" &
  PROXY_PID=$!

  # Give the proxy time to establish the tunnel
  echo "   Waiting for proxy tunnel to establish..."
  sleep 15

  # Verify the tunnel is working
  if ! kubectl get nodes &>/dev/null; then
    echo "❌ Cluster Connect proxy failed. Ensure the cluster is Arc-connected and try again."
    [ -n "$PROXY_PID" ] && kill "$PROXY_PID" 2>/dev/null || true
    exit 1
  fi
fi

# Cleanup proxy on exit (only if we started one)
trap '[ -n "$PROXY_PID" ] && kill "$PROXY_PID" 2>/dev/null || true' EXIT

echo "✅ Cluster Connect active — kubectl is working via Azure Arc"
echo ""
echo "🚀 Deploying application..."
kubectl apply -f k8s/demo-app.yaml

echo ""
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=nginx-demo -n demo --timeout=120s

echo ""
echo "--- Demo Application Status ---"
kubectl get all -n demo

echo ""
echo "============================================"
echo "  ✅ Application 1 (nginx-demo) deployed via Cluster Connect!"
echo "  No SSH, no VPN — just Azure Arc."
echo "============================================"

# ============================================================================
# Step 2: Deploy second container via Azure Portal (manual)
#   Demonstrate that you can deploy workloads directly from the Azure Portal
#   by pasting YAML — no CLI required.
# ============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Deploy 2nd container via Azure Portal"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Now open the Azure Portal and deploy a second container manually:"
echo "   1. Go to: Arc cluster ($CLUSTER_NAME) > Kubernetes resources > Workloads"
echo "   2. Click '+ Create' > 'Apply with YAML'"
echo "   3. Paste the contents of: k8s/hello-arc.yaml"
echo "   4. Click 'Add' and wait for the pod to be Running"
echo ""
echo "📄 YAML to paste (also available at k8s/hello-arc.yaml):"
echo "─────────────────────────────────────────────"
cat k8s/hello-arc.yaml
echo "─────────────────────────────────────────────"

echo ""
echo "⏸️  Deploy the YAML above via the Azure Portal, then press Enter to verify..."
read -r

# Verify both deployments
echo "🔍 Verifying both deployments..."
kubectl get deployments -n demo
kubectl get pods -n demo

echo ""
echo "============================================"
echo "  ✅ Two containers running on-prem via Azure Arc!"
echo "  - nginx-demo  (deployed via CLI / Cluster Connect)"
echo "  - hello-arc   (deployed via Azure Portal)"
echo "  View in Portal: Arc cluster > Kubernetes resources > Workloads"
echo "============================================"
