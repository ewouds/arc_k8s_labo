#!/bin/bash
# ============================================================================
# Script 03 - Azure Arc Onboarding
# Connects the K3s cluster to Azure Arc
# Run this ON THE VM via SSH (after 02-install-k3s.sh)
# ============================================================================
set -e

echo "============================================"
echo "  Azure Arc - Cluster Onboarding"
echo "============================================"

# --- Configuration ---
# These values should match your AZD deployment
# Get them with: azd env get-values (on your local machine)
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arcworkshop}"
CLUSTER_NAME="${CLUSTER_NAME:-arc-k3s-cluster}"
LOCATION="${LOCATION:-westeurope}"

echo ""
echo "📋 Configuration:"
echo "  Resource Group: $RESOURCE_GROUP"
echo "  Cluster Name:   $CLUSTER_NAME"
echo "  Location:       $LOCATION"

# --- 1. Install Azure CLI on the VM ---
echo ""
echo "📦 Installing Azure CLI..."
if ! command -v az &>/dev/null; then
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
else
  echo "  ✅ Azure CLI already installed ($(az version --query '\"azure-cli\"' -o tsv))"
fi

# --- 2. Login to Azure ---
echo ""
echo "🔐 Logging in to Azure..."
echo "  (Use device code flow since we're on a remote VM)"
az login --use-device-code

# Set the correct subscription (uncomment and set if needed)
# az account set --subscription "<YOUR_SUBSCRIPTION_ID>"

# --- 3. Install required CLI extensions ---
echo ""
echo "📦 Installing Azure CLI extensions..."
az extension add --name connectedk8s --yes 2>/dev/null || az extension update --name connectedk8s
az extension add --name k8s-configuration --yes 2>/dev/null || az extension update --name k8s-configuration
az extension add --name k8s-extension --yes 2>/dev/null || az extension update --name k8s-extension

# --- 4. Ensure KUBECONFIG is set ---
export KUBECONFIG=~/.kube/config

echo ""
echo "🔍 Verifying kubectl access..."
kubectl get nodes

# --- 5. Connect the cluster to Azure Arc ---
echo ""
echo "🔗 Connecting K3s cluster to Azure Arc..."
echo "  This installs Arc agents in the 'azure-arc' namespace"
echo "  The agents maintain an outbound connection to Azure"
echo ""

az connectedk8s connect \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --correlation-id "arc-k8s-workshop-demo"

# --- 6. Verify the connection ---
echo ""
echo "🔍 Verifying Arc connection..."
echo ""
echo "--- Arc Agent Status ---"
az connectedk8s show \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query '{name:name, connectivityStatus:connectivityStatus, kubernetesVersion:kubernetesVersion, totalNodeCount:totalNodeCount, agentVersion:agentVersion}' \
  -o table

echo ""
echo "--- Arc Agent Pods ---"
kubectl get pods -n azure-arc

echo ""
echo "--- Arc Agent Deployments ---"
kubectl get deployments -n azure-arc

# --- 7. Enable Cluster Connect feature ---
echo ""
echo "🔌 Enabling Cluster Connect feature..."
echo "  This allows kubectl access via Azure Arc (no VPN/SSH needed)"
az connectedk8s enable-features \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --features cluster-connect

echo "  ✅ Cluster Connect enabled"

# --- 8. Grant signed-in user cluster-admin for Cluster Connect RBAC ---
echo ""
echo "🔐 Configuring Kubernetes RBAC for Cluster Connect..."
AZURE_USER=$(az ad signed-in-user show --query userPrincipalName -o tsv)
echo "  Granting cluster-admin to: $AZURE_USER"
kubectl create clusterrolebinding arc-admin-binding \
  --clusterrole=cluster-admin \
  --user="$AZURE_USER" 2>/dev/null \
  || echo "  (binding already exists)"
echo "  ✅ RBAC configured"

echo ""
echo "============================================"
echo "  ✅ Cluster successfully connected to Azure Arc!"
echo ""
echo "  View in Azure Portal:"
echo "  https://portal.azure.com/#blade/HubsExtension/BrowseResource/resourceType/Microsoft.Kubernetes%2FconnectedClusters"
echo ""
echo "  Next: Deploy a container from Azure (step 04)"
echo "============================================"
