#!/bin/bash
# ============================================================================
# Script 05 - Consistent Governance & Compliance with Azure Policy
# Run from your LOCAL machine
# ============================================================================
set -e

echo "============================================"
echo "  Azure Policy for Kubernetes (Arc)"
echo "============================================"

# --- Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arcworkshop}"
CLUSTER_NAME="${CLUSTER_NAME:-arc-k3s-cluster}"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo ""
echo "📋 Configuration:"
echo "  Resource Group:  $RESOURCE_GROUP"
echo "  Cluster Name:    $CLUSTER_NAME"
echo "  Subscription:    $SUBSCRIPTION_ID"

# --- 1. Install Azure Policy extension on Arc cluster ---
echo ""
echo "📦 Installing Azure Policy extension on the Arc cluster..."
echo "  This deploys Gatekeeper (OPA) on the cluster to enforce policies."

az k8s-extension create \
  --name azurepolicy \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --extension-type Microsoft.PolicyInsights

echo ""
echo "⏳ Waiting for extension to be provisioned..."
az k8s-extension show \
  --name azurepolicy \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --query '{name:name, provisioningState:provisioningState, extensionType:extensionType}' \
  -o table

# --- 2. Assign built-in policies ---
echo ""
echo "📜 Assigning Azure Policies to the cluster..."

# Get the Arc cluster resource ID
CLUSTER_ID=$(az connectedk8s show \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)

# Policy 1: Kubernetes clusters should not allow privileged containers
echo ""
echo "  📌 Policy: Do not allow privileged containers"
POLICY_DEF_1="95edb821-ddaf-4404-9732-666045e056b4"
az policy assignment create \
  --name "no-privileged-containers" \
  --display-name "[Arc Workshop] Do not allow privileged containers" \
  --policy "$POLICY_DEF_1" \
  --scope "$CLUSTER_ID" \
  --params '{"effect": {"value": "Deny"}}' \
  2>/dev/null || echo "  (Policy may already be assigned)"

# Policy 2: Kubernetes clusters should use internal load balancers
echo ""
echo "  📌 Policy: Enforce resource labels (require 'environment' label)"
POLICY_DEF_2="46592696-4c7b-4bf3-9e45-6c2763bdc0a6"
az policy assignment create \
  --name "require-env-label" \
  --display-name "[Arc Workshop] Pods must have 'environment' label" \
  --policy "$POLICY_DEF_2" \
  --scope "$CLUSTER_ID" \
  --params '{"effect": {"value": "Deny"}, "labelsList": {"value": ["environment"]}}' \
  2>/dev/null || echo "  (Policy may already be assigned)"

# Policy 3: Container images should only use allowed registries
echo ""
echo "  📌 Policy: Allow only trusted container registries"
POLICY_DEF_3="febd0533-8e55-448f-b837-bd0e06f16469"
az policy assignment create \
  --name "allowed-registries" \
  --display-name "[Arc Workshop] Only allow trusted registries" \
  --policy "$POLICY_DEF_3" \
  --scope "$CLUSTER_ID" \
  --params '{"effect": {"value": "Deny"}, "allowedContainerImagesRegex": {"value": "^(docker\\.io|mcr\\.microsoft\\.com|ghcr\\.io)/.*$"}}' \
  2>/dev/null || echo "  (Policy may already be assigned)"

# --- 3. Show compliance status ---
echo ""
echo "📊 Policy Compliance (may take 15-30 min to evaluate)..."
echo ""
echo "  To check compliance status later:"
echo "  az policy state summarize --resource \"$CLUSTER_ID\""
echo ""
echo "  Or view in Azure Portal:"
echo "  Arc cluster > Policies"

echo ""
echo "============================================"
echo "  ✅ Azure Policy configured!"
echo ""
echo "  Policies assigned:"
echo "    1. No privileged containers (Deny)"
echo "    2. Require 'environment' label (Deny)"
echo "    3. Only trusted registries (Deny)"
echo ""
echo "  🎯 Demo: Try deploying a privileged pod - it will be blocked!"
echo "     kubectl apply -f k8s/privileged-pod.yaml  # Will fail"
echo "============================================"
