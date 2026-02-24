#!/bin/bash
# ============================================================================
# Script 99 - Cleanup All Workshop Resources
# Run from your LOCAL machine
# ============================================================================

echo "============================================"
echo "  🧹 Cleanup Workshop Resources"
echo "============================================"

# --- Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arcworkshop}"
CLUSTER_NAME="${CLUSTER_NAME:-arc-k3s-cluster}"

echo ""
echo "⚠️  This will delete ALL resources created during the workshop!"
echo "  Resource Group: $RESOURCE_GROUP"
echo ""
read -p "Are you sure? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Cancelled."
  exit 0
fi

# --- 1. Remove Arc GitOps configurations ---
echo ""
echo "🗑️ Removing GitOps configurations..."
az k8s-configuration flux delete \
  --name demo-gitops \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --yes 2>/dev/null || true

# --- 2. Remove Arc extensions ---
echo ""
echo "🗑️ Removing Arc extensions..."
for EXT in azuremonitor-containers microsoft.azuredefender.kubernetes azurepolicy flux; do
  echo "  Removing $EXT..."
  az k8s-extension delete \
    --name "$EXT" \
    --cluster-name "$CLUSTER_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --cluster-type connectedClusters \
    --yes 2>/dev/null || true
done

# --- 3. Disconnect the Arc cluster ---
echo ""
echo "🗑️ Disconnecting Arc cluster..."
az connectedk8s delete \
  --name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --yes 2>/dev/null || true

# --- 4. Remove policy assignments ---
echo ""
echo "🗑️ Removing policy assignments..."
for ASSIGNMENT in no-privileged-containers require-env-label allowed-registries; do
  az policy assignment delete --name "$ASSIGNMENT" 2>/dev/null || true
done

# --- 5. Delete the resource group (removes VM, VNet, Log Analytics, etc.) ---
echo ""
echo "🗑️ Deleting resource group $RESOURCE_GROUP..."
echo "  This may take a few minutes..."
az group delete --name "$RESOURCE_GROUP" --yes --no-wait

# --- 5a. Delete optional AKS resource group (if created via 09a) ---
if [ "$(az group exists --name rg-arcworkshop-aks 2>/dev/null)" = "true" ]; then
  echo ""
  echo "🗑️ Deleting optional AKS resource group (rg-arcworkshop-aks)..."
  az group delete --name "rg-arcworkshop-aks" --yes --no-wait
fi

# --- 6. Or use AZD to clean up ---
echo ""
echo "  Alternatively, you can run:"
echo "    azd down --purge --force"

echo ""
echo "============================================"
echo "  ✅ Cleanup initiated!"
echo "  Resource group deletion is running in the background."
echo "============================================"
