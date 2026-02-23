# ============================================================================
# Script 06 - Microsoft Defender for Containers
# Run from your LOCAL machine (PowerShell)
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Microsoft Defender for Containers (Arc)"  -ForegroundColor Cyan
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

# --- 1. Enable Defender for Containers plan ---
Write-Host ""
Write-Host "🛡️ Enabling Defender for Containers plan..." -ForegroundColor Yellow
az security pricing create --name Containers --tier Standard 2>$null
Write-Host "  ✅ Defender plan enabled" -ForegroundColor Green

# --- 2. Install Defender extension ---
Write-Host ""
Write-Host "📦 Installing Defender extension on Arc cluster..." -ForegroundColor Yellow

az k8s-extension create `
  --name microsoft.azuredefender.kubernetes `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --extension-type microsoft.azuredefender.kubernetes `
  --configuration-settings "logAnalyticsWorkspaceResourceID=$workspaceId" 2>$null

Write-Host ""
Write-Host "⏳ Checking extension status..." -ForegroundColor DarkYellow
az k8s-extension show `
  --name microsoft.azuredefender.kubernetes `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --query '{name:name, provisioningState:provisioningState, extensionType:extensionType}' `
  -o table

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  What Defender provides:" -ForegroundColor White
Write-Host "  🔍 Runtime threat detection" 
Write-Host "  📦 Image vulnerability scanning"
Write-Host "  🔒 Security recommendations"
Write-Host "  📊 View: Defender for Cloud > Workload protections" 
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ Microsoft Defender configured!"        -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
