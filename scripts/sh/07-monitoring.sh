#!/bin/bash
# ============================================================================
# Script 07 - Centralized Monitoring & Observability
# Container Insights + Azure Monitor for Arc-enabled K8s
# Run from your LOCAL machine
# ============================================================================
set -e

echo "============================================"
echo "  Azure Monitor & Container Insights (Arc)"
echo "============================================"

# --- Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arcworkshop}"
CLUSTER_NAME="${CLUSTER_NAME:-arc-k3s-cluster}"
LOG_ANALYTICS_WORKSPACE_ID="${LOG_ANALYTICS_WORKSPACE_ID:-$(azd env get-values 2>/dev/null | grep LOG_ANALYTICS_WORKSPACE_ID | cut -d'=' -f2 | tr -d '"')}"

echo ""
echo "📋 Configuration:"
echo "  Resource Group:  $RESOURCE_GROUP"
echo "  Cluster Name:    $CLUSTER_NAME"
echo "  Workspace:       $LOG_ANALYTICS_WORKSPACE_ID"

# --- 1. Install Azure Monitor extension (Container Insights) ---
echo ""
echo "📦 Installing Azure Monitor extension..."
echo "  This deploys the Azure Monitor agent (AMA) on the cluster"
echo "  to collect container logs, metrics, and performance data."

az k8s-extension create \
  --name azuremonitor-containers \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --extension-type Microsoft.AzureMonitor.Containers \
  --configuration-settings "logAnalyticsWorkspaceResourceID=$LOG_ANALYTICS_WORKSPACE_ID" \
  2>/dev/null || echo "  (Extension may already exist)"

echo ""
echo "⏳ Checking extension status..."
az k8s-extension show \
  --name azuremonitor-containers \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --query '{name:name, provisioningState:provisioningState, extensionType:extensionType}' \
  -o table

# --- 2. List all installed extensions ---
echo ""
echo "📋 All extensions installed on the Arc cluster:"
az k8s-extension list \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --query '[].{Name:name, Type:extensionType, State:provisioningState}' \
  -o table

# --- 3. Example KQL queries for Container Insights ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Useful KQL Queries for Container Insights"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  📊 1. Container CPU/Memory usage:"
echo '    Perf'
echo '    | where ObjectName == "K8SContainer"'
echo '    | where CounterName in ("cpuUsageNanoCores", "memoryWorkingSetBytes")'
echo '    | summarize avg(CounterValue) by CounterName, InstanceName, bin(TimeGenerated, 5m)'
echo '    | render timechart'
echo ""
echo "  📊 2. Pod status overview:"
echo '    KubePodInventory'
echo '    | where TimeGenerated > ago(1h)'
echo '    | summarize count() by PodStatus, Namespace'
echo '    | render piechart'
echo ""
echo "  📊 3. Container logs (stderr):"
echo '    ContainerLogV2'
echo '    | where LogLevel == "error"'
echo '    | project TimeGenerated, PodName, LogMessage'
echo '    | order by TimeGenerated desc'
echo '    | take 50'
echo ""
echo "  📊 4. Node resource utilization:"
echo '    InsightsMetrics'
echo '    | where Namespace == "container.azm.ms/node"'
echo '    | where Name in ("cpuUsagePercentage", "memoryWorkingSetPercentage")'
echo '    | summarize avg(Val) by Name, Computer, bin(TimeGenerated, 5m)'
echo '    | render timechart'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Portal Navigation for Demo"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  1. Arc cluster > Insights (Container Insights dashboard)"
echo "  2. Arc cluster > Logs (KQL query editor)"
echo "  3. Arc cluster > Workbooks (pre-built visualizations)"
echo "  4. Azure Monitor > Containers (multi-cluster view)"

echo ""
echo "============================================"
echo "  ✅ Azure Monitor & Container Insights configured!"
echo ""
echo "  ⏳ Data will start appearing in ~5-10 minutes"
echo "  📊 Open Azure Portal to explore dashboards"
echo "============================================"
