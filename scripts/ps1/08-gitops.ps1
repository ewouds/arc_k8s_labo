# ============================================================================
# Script 08 - GitOps with Flux v2 on Azure Arc
# Run from your LOCAL machine (PowerShell)
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  GitOps with Flux v2 (Arc-enabled K8s)"   -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Configuration ---
$resourceGroup = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-arcworkshop" }
$clusterName   = if ($env:CLUSTER_NAME)   { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }
$gitopsRepoUrl = "https://github.com/Azure/arc-k8s-demo"
$gitopsBranch  = "main"

Write-Host ""
Write-Host "📋 Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Cluster Name:   $clusterName"
Write-Host "  GitOps Repo:    $gitopsRepoUrl"

# --- 1. Install Flux extension ---
Write-Host ""
Write-Host "📦 Installing Flux extension..." -ForegroundColor Yellow

az k8s-extension create `
  --name flux `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --extension-type microsoft.flux 2>$null

Write-Host ""
Write-Host "⏳ Verifying Flux extension..." -ForegroundColor DarkYellow
az k8s-extension show `
  --name flux `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --query '{name:name, provisioningState:provisioningState}' `
  -o table

# --- 2. Create GitOps Flux configuration ---
Write-Host ""
Write-Host "🔗 Creating Flux GitOps configuration..." -ForegroundColor Yellow

az k8s-configuration flux create `
  --name demo-gitops `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --namespace gitops-demo `
  --scope cluster `
  --url $gitopsRepoUrl `
  --branch $gitopsBranch `
  --kustomization name=cluster-config path=./releases/prod prune=true 2>$null

# --- 3. Show status ---
Write-Host ""
Write-Host "📊 GitOps configuration status:" -ForegroundColor Yellow
az k8s-configuration flux list `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --query '[].{Name:name, Scope:scope, Compliance:complianceState, Url:gitRepository.url}' `
  -o table

# --- 4. Explain the workflow ---
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  GitOps Workflow:" -ForegroundColor White
Write-Host "  1. Dev pushes to Git"
Write-Host "  2. Flux detects change (pull-based)"
Write-Host "  3. Flux applies to cluster"
Write-Host "  4. Azure shows compliance"
Write-Host ""
Write-Host "  Benefits:"
Write-Host "  • Same flow for Arc + AKS"
Write-Host "  • Drift auto-remediation"
Write-Host "  • Audit trail via Git"
Write-Host ""
Write-Host "  Portal: Arc cluster > GitOps"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host ""
Write-Host "============================================"                        -ForegroundColor Cyan
Write-Host "  ✅ GitOps configured!"                                             -ForegroundColor Green
Write-Host "  🔄 Flux watches: $gitopsRepoUrl"                                   -ForegroundColor Cyan
Write-Host "============================================"                        -ForegroundColor Cyan
