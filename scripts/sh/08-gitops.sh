#!/bin/bash
# ============================================================================
# Script 08 - GitOps-Based Configuration & Application Deployment
# Uses Flux v2 for GitOps on Arc-enabled Kubernetes
# Run from your LOCAL machine
# ============================================================================
set -e

echo "============================================"
echo "  GitOps with Flux v2 on Azure Arc"
echo "============================================"

# --- Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arcworkshop}"
CLUSTER_NAME="${CLUSTER_NAME:-arc-k3s-cluster}"

# GitOps source repository
# Using the local gitops/ folder pushed to a Git repo, or the Azure sample repo
GITOPS_REPO_URL="${GITOPS_REPO_URL:-https://github.com/ewouds/arc_k8s_labo}"
GITOPS_BRANCH="${GITOPS_BRANCH:-master}"

echo ""
echo "📋 Configuration:"
echo "  Resource Group:  $RESOURCE_GROUP"
echo "  Cluster Name:    $CLUSTER_NAME"
echo "  GitOps Repo:     $GITOPS_REPO_URL"
echo "  Branch:          $GITOPS_BRANCH"

# --- 1. Install Flux extension ---
echo ""
echo "📦 Installing Flux extension on the Arc cluster..."
echo "  Flux is the GitOps operator that:"
echo "    - Watches a Git repository for changes"
echo "    - Automatically syncs desired state to the cluster"
echo "    - Supports Kustomize and Helm"

az k8s-extension create \
  --name flux \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --extension-type microsoft.flux \
  2>/dev/null || echo "  (Flux extension may already be installed)"

echo ""
echo "⏳ Verifying Flux extension..."
az k8s-extension show \
  --name flux \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --query '{name:name, provisioningState:provisioningState}' \
  -o table

# --- 2. Create a GitOps (Flux) configuration ---
echo ""
echo "🔗 Creating Flux configuration..."
echo "  This tells Flux to watch the Git repo and apply changes"

az k8s-configuration flux create \
  --name cluster-config \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --namespace flux-system \
  --scope cluster \
  --url "$GITOPS_REPO_URL" \
  --branch "$GITOPS_BRANCH" \
  --kustomization name=cluster-apps path=./gitops prune=true

# --- 3. Verify the GitOps configuration ---
echo ""
echo "🔍 Verifying GitOps configuration..."
az k8s-configuration flux show \
  --name cluster-config \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --query '{name:name, complianceState:complianceState, provisioningState:provisioningState}' \
  -o table

# --- 4. (Optional) Create a second configuration for the local gitops/ folder ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Optional: Use YOUR OWN GitOps repo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Push the gitops/ folder from this project to your GitHub repo"
echo "  2. Then run:"
echo ""
echo "  az k8s-configuration flux create \\"
echo "    --name my-app-config \\"
echo "    --cluster-name $CLUSTER_NAME \\"
echo "    --resource-group $RESOURCE_GROUP \\"
echo "    --cluster-type connectedClusters \\"
echo "    --namespace gitops-demo \\"
echo "    --scope namespace \\"
echo "    --url https://github.com/YOUR_ORG/YOUR_REPO \\"
echo "    --branch main \\"
echo "    --kustomization name=apps path=./gitops prune=true"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  GitOps Workflow Demo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Make a change in the Git repo (e.g., update replica count)"
echo "  2. Commit & push to the branch"
echo "  3. Flux detects the change (default: every 10 minutes, configurable)"
echo "  4. Flux applies the new state to the cluster"
echo "  5. Compliance state updates in Azure Portal"
echo ""
echo "  📊 View in Portal:"
echo "     Arc cluster > GitOps > cluster-config"

echo ""
echo "============================================"
echo "  ✅ GitOps with Flux configured!"
echo ""
echo "  📂 Flux watches: $GITOPS_REPO_URL"
echo "  🔄 Sync interval: 10 minutes (default)"
echo "  📊 View: Portal > Arc cluster > GitOps"
echo "============================================"
