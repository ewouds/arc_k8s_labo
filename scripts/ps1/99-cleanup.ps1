# ============================================================================
# Script 99 - Cleanup All Workshop Resources
# Run from your LOCAL machine (PowerShell)
# ============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  🧹 Cleanup Workshop Resources"           -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

$resourceGroup = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-arcworkshop" }
$clusterName   = if ($env:CLUSTER_NAME)   { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }

Write-Host ""
Write-Host "⚠️  This will delete ALL resources:" -ForegroundColor Red
Write-Host "  Resource Group: $resourceGroup"
Write-Host ""

$confirm = Read-Host "Are you sure? (y/N)"
if ($confirm -notin @('y', 'Y')) {
    Write-Host "Cancelled." -ForegroundColor DarkYellow
    exit 0
}

# --- 1. Remove GitOps configs ---
Write-Host ""
Write-Host "🗑️ Removing GitOps configurations..." -ForegroundColor Yellow
az k8s-configuration flux delete `
  --name demo-gitops `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --yes 2>$null

# --- 2. Remove extensions ---
Write-Host ""
Write-Host "🗑️ Removing Arc extensions..." -ForegroundColor Yellow
$extensions = @("azuremonitor-containers", "microsoft.azuredefender.kubernetes", "azurepolicy", "flux")
foreach ($ext in $extensions) {
    Write-Host "  Removing $ext..."
    az k8s-extension delete `
      --name $ext `
      --cluster-name $clusterName `
      --resource-group $resourceGroup `
      --cluster-type connectedClusters `
      --yes 2>$null
}

# --- 3. Disconnect Arc ---
Write-Host ""
Write-Host "🗑️ Disconnecting Arc cluster..." -ForegroundColor Yellow
az connectedk8s delete `
  --name $clusterName `
  --resource-group $resourceGroup `
  --yes 2>$null

# --- 4. Remove policy assignments ---
Write-Host ""
Write-Host "🗑️ Removing policy assignments..." -ForegroundColor Yellow
@("no-privileged-containers", "require-env-label", "allowed-registries") | ForEach-Object {
    az policy assignment delete --name $_ 2>$null
}

# --- 5. Delete resource group ---
Write-Host ""
Write-Host "🗑️ Deleting resource group $resourceGroup..." -ForegroundColor Yellow
az group delete --name $resourceGroup --yes --no-wait

Write-Host ""
Write-Host "  Or use: azd down --purge --force" -ForegroundColor DarkYellow

Write-Host ""
Write-Host "============================================"                     -ForegroundColor Cyan
Write-Host "  ✅ Cleanup initiated (running in background)"                   -ForegroundColor Green
Write-Host "============================================"                     -ForegroundColor Cyan
