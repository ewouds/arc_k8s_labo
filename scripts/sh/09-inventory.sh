#!/bin/bash
# ============================================================================
# Script 09 - Inventory Management with Azure Resource Graph
# Run from your LOCAL machine
# ============================================================================
set -e

echo "============================================"
echo "  Arc Inventory & Resource Graph Queries"
echo "============================================"

# --- Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arcworkshop}"
CLUSTER_NAME="${CLUSTER_NAME:-arc-k3s-cluster}"

# --- 1. List all Arc-connected clusters ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. All Arc-connected K8s clusters"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

az graph query -q "
  resources
  | where type == 'microsoft.kubernetes/connectedclusters'
  | project name, resourceGroup, location, 
            k8sVersion=properties.kubernetesVersion,
            nodes=properties.totalNodeCount,
            status=properties.connectivityStatus,
            distribution=properties.distribution,
            agentVersion=properties.agentVersion
  | order by name asc
" -o table

# --- 2. Cluster details with extensions ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  2. Extensions installed per cluster"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

az k8s-extension list \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --query '[].{Name:name, Type:extensionType, State:provisioningState, Version:version}' \
  -o table

# --- 3. Compliance status across clusters ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  3. Policy compliance across all Arc clusters"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

az graph query -q "
  policyresources
  | where type == 'microsoft.policyinsights/policystates'
  | where properties.resourceType == 'microsoft.kubernetes/connectedclusters'
  | summarize 
      compliant=countif(properties.complianceState == 'Compliant'),
      nonCompliant=countif(properties.complianceState == 'NonCompliant')
    by tostring(properties.resourceId)
" -o table 2>/dev/null || echo "  (No policy data yet - policies need time to evaluate)"

# --- 4. All Arc K8s resources across subscriptions ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  4. Cross-subscription Arc inventory"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

az graph query -q "
  resources
  | where type in (
      'microsoft.kubernetes/connectedclusters',
      'microsoft.containerservice/managedclusters'
    )
  | extend clusterType = case(
      type == 'microsoft.kubernetes/connectedclusters', 'Arc-connected',
      type == 'microsoft.containerservice/managedclusters', 'AKS (managed)',
      'Unknown'
    )
  | project name, clusterType, resourceGroup, location,
            subscriptionId,
            k8sVersion=properties.kubernetesVersion,
            nodes=properties.totalNodeCount
  | order by clusterType, name
" -o table

# --- 5. GitOps configurations across clusters ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  5. GitOps configurations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

az k8s-configuration flux list \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --query '[].{Name:name, Repo:gitRepository.url, Compliance:complianceState, State:provisioningState}' \
  -o table 2>/dev/null || echo "  (No GitOps configurations found)"

# --- 6. Custom Resource Graph queries ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  6. Additional useful queries"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  🔍 Disconnected clusters (last seen > 1 hour):"
echo '  az graph query -q "'
echo "    resources"
echo "    | where type == 'microsoft.kubernetes/connectedclusters'"
echo "    | where properties.connectivityStatus != 'Connected'"
echo "    | project name, resourceGroup, status=properties.connectivityStatus,"
echo "              lastSeen=properties.lastConnectivityTime"
echo '  "'
echo ""
echo "  🔍 Clusters by Kubernetes version:"
echo '  az graph query -q "'
echo "    resources"
echo "    | where type == 'microsoft.kubernetes/connectedclusters'"
echo "    | summarize count() by tostring(properties.kubernetesVersion)"
echo '  "'
echo ""
echo "  🔍 Clusters without monitoring extension:"
echo '  az graph query -q "'
echo "    resources"
echo "    | where type == 'microsoft.kubernetes/connectedclusters'"
echo "    | join kind=leftanti ("
echo "      resources"
echo "      | where type == 'microsoft.kubernetesconfiguration/extensions'"
echo "      | where properties.extensionType == 'Microsoft.AzureMonitor.Containers'"
echo "    ) on subscriptionId"
echo '  "'

echo ""
echo "============================================"
echo "  ✅ Inventory management demo complete!"
echo ""
echo "  📊 Portal: Azure Resource Graph Explorer"
echo "  📊 Portal: Arc > Kubernetes clusters (overview)"
echo "============================================"
