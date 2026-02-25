# ============================================================================
# Script 09 - Inventory Management with Azure Resource Graph
# Run from your LOCAL machine (PowerShell)
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Arc K8s Inventory Management"             -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$resourceGroup = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-arcworkshop" }
$clusterName   = if ($env:CLUSTER_NAME)   { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }

# --- 1. All Arc-connected clusters ---
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Query 1: All Arc-connected clusters" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray

az graph query -q @"
resources
| where type =~ 'microsoft.kubernetes/connectedclusters'
| project name, resourceGroup, location,
          k8sVersion=properties.kubernetesVersion,
          nodes=properties.totalNodeCount,
          status=properties.connectivityStatus,
          distribution=properties.distribution
| order by name asc
"@ -o table

# --- 2. K8s version distribution ---
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Query 2: K8s version distribution" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray

az graph query -q @"
resources
| where type =~ 'microsoft.kubernetes/connectedclusters'
| summarize ClusterCount=count() by
    K8sVersion=tostring(properties.kubernetesVersion),
    Distribution=tostring(properties.distribution)
| order by ClusterCount desc
"@ -o table

# --- 3. Extensions per cluster ---
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Query 3: Extensions installed" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray

az k8s-extension list `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --query '[].{Name:name, Type:extensionType, State:provisioningState, Version:version}' `
  -o table

# --- 4. Arc + AKS side by side ---
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Query 4: Arc + AKS clusters combined" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray

az graph query -q @"
resources
| where type in (
    'microsoft.kubernetes/connectedclusters',
    'microsoft.containerservice/managedclusters')
| extend clusterType = iff(type contains 'connected', 'Arc', 'AKS')
| project name, clusterType, resourceGroup, location,
          k8sVersion=properties.kubernetesVersion
| order by clusterType, name
"@ -o table

# --- 5. GitOps configurations ---
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Query 5: GitOps configurations" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray

az k8s-configuration flux list `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --query '[].{Name:name, Repo:gitRepository.url, Compliance:complianceState}' `
  -o table 2>$null

Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Portal: Resource Graph Explorer" -ForegroundColor White
Write-Host "  Portal: Arc > Kubernetes clusters" 
Write-Host "==========================================" -ForegroundColor DarkGray

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  [OK] Inventory queries complete!"           -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
