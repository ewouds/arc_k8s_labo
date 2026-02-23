# ============================================================================
# Script 07 - Centralized Monitoring & Observability
# Container Insights + Azure Monitor for Arc-enabled K8s
# Run from your LOCAL machine (PowerShell)
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Azure Monitor - Container Insights (Arc)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Configuration ---
$resourceGroup = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-arcworkshop" }
$clusterName   = if ($env:CLUSTER_NAME)   { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }
$workspaceId   = (azd env get-value LOG_ANALYTICS_WORKSPACE_ID 2>$null)
if (-not $workspaceId) { $workspaceId = Read-Host "Enter Log Analytics Workspace Resource ID" }

Write-Host ""
Write-Host "📋 Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Cluster Name:   $clusterName"
Write-Host "  Workspace:      $workspaceId"

# --- 1. Install Container Insights extension ---
Write-Host ""
Write-Host "📦 Installing Azure Monitor extension (Container Insights)..." -ForegroundColor Yellow

az k8s-extension create `
  --name azuremonitor-containers `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --extension-type Microsoft.AzureMonitor.Containers `
  --configuration-settings "logAnalyticsWorkspaceResourceID=$workspaceId" 2>$null

Write-Host ""
Write-Host "⏳ Checking extension status..." -ForegroundColor DarkYellow
az k8s-extension show `
  --name azuremonitor-containers `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --query '{name:name, provisioningState:provisioningState, extensionType:extensionType}' `
  -o table

# --- 2. List all extensions ---
Write-Host ""
Write-Host "📦 All extensions installed:" -ForegroundColor Yellow
az k8s-extension list `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --query '[].{Name:name, Type:extensionType, State:provisioningState}' `
  -o table

# --- 3. KQL Query examples ---
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Sample KQL Queries" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  // Pod status overview:" -ForegroundColor DarkYellow
Write-Host '  KubePodInventory | summarize count() by PodStatus, Namespace | render piechart'
Write-Host ""
Write-Host "  // Container CPU:" -ForegroundColor DarkYellow
Write-Host '  Perf | where ObjectName == "K8SContainer" | where CounterName == "cpuUsageNanoCores"'
Write-Host '  | summarize avg(CounterValue) by InstanceName, bin(TimeGenerated, 5m) | render timechart'
Write-Host ""
Write-Host "  // Container logs:" -ForegroundColor DarkYellow
Write-Host '  ContainerLogV2 | project TimeGenerated, PodName, LogMessage | order by TimeGenerated desc | take 50'

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Portal Views:" -ForegroundColor White
Write-Host "  1. Arc cluster > Insights (dashboards)"
Write-Host "  2. Arc cluster > Logs (KQL editor)"
Write-Host "  3. Arc cluster > Workbooks"
Write-Host "  4. Azure Monitor > Containers (multi-cluster)"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ Container Insights configured!"        -ForegroundColor Green
Write-Host "  Data appears in ~5-10 min."               -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
