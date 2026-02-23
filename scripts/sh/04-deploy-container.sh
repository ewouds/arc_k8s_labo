#!/bin/bash
# ============================================================================
# Script 04 - Deploy Container from Azure to Arc-connected Cluster
# Run this from your LOCAL machine (not the VM)
# Demonstrates deploying workloads to Arc-connected clusters from Azure
# ============================================================================
set -e

echo "============================================"
echo "  Deploy Container via Azure Arc"
echo "============================================"

# --- Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arcworkshop}"
CLUSTER_NAME="${CLUSTER_NAME:-arc-k3s-cluster}"
VM_IP="${VM_IP:-$(azd env get-values 2>/dev/null | grep VM_PUBLIC_IP | cut -d'=' -f2 | tr -d '"')}"

echo ""
echo "📋 Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Cluster Name:   $CLUSTER_NAME"
echo "  VM IP:          $VM_IP"

# ============================================================================
# METHOD 1: Using cluster connect (az connectedk8s proxy)
# This creates a secure tunnel from your local machine to the Arc cluster
# ============================================================================

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Method 1: Cluster Connect (az connectedk8s proxy)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  This feature lets you access the K8s API from your local"
echo "  machine through Azure, without needing direct network access."
echo ""
echo "  Step 1: Start the proxy (run in a separate terminal):"
echo "    az connectedk8s proxy -n $CLUSTER_NAME -g $RESOURCE_GROUP &"
echo ""
echo "  Step 2: Use kubectl as if the cluster were local:"
echo "    kubectl get nodes"
echo "    kubectl apply -f k8s/demo-app.yaml"
echo ""

# ============================================================================
# METHOD 2: Direct deployment via SSH + kubectl
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Method 2: Deploy via SSH + kubectl"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Copying manifest and applying on the remote cluster..."

# Copy the manifest to the VM
scp -o StrictHostKeyChecking=no k8s/demo-app.yaml azureuser@${VM_IP}:~/demo-app.yaml

# Apply the manifest on the VM
ssh -o StrictHostKeyChecking=no azureuser@${VM_IP} << 'REMOTE_COMMANDS'
echo ""
echo "📦 Creating demo namespace and deploying application..."
export KUBECONFIG=~/.kube/config
kubectl apply -f ~/demo-app.yaml

echo ""
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=nginx-demo -n demo --timeout=120s

echo ""
echo "--- Demo Application Status ---"
kubectl get all -n demo
REMOTE_COMMANDS

echo ""
echo "============================================"
echo "  ✅ Application deployed to Arc-connected cluster!"
echo ""
echo "  View workloads in Azure Portal:"
echo "  Arc cluster > Kubernetes resources > Workloads"
echo ""
echo "  The deployment is visible from Azure even though"
echo "  the cluster runs 'on-premises' (on our VM)."
echo "============================================"
