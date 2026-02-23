# ============================================================================
# Script 05 - Governance & Compliance with Azure Policy
# Run from your LOCAL machine (PowerShell)
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Azure Policy for Kubernetes (Arc)"        -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Configuration ---
$resourceGroup = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-arcworkshop" }
$clusterName   = if ($env:CLUSTER_NAME)   { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }

Write-Host ""
Write-Host "📋 Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Cluster Name:   $clusterName"

# --- 1. Install Azure Policy extension ---
Write-Host ""
Write-Host "📦 Installing Azure Policy extension (OPA Gatekeeper)..." -ForegroundColor Yellow

az k8s-extension create `
  --name azurepolicy `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --extension-type Microsoft.PolicyInsights

Write-Host ""
Write-Host "⏳ Checking extension status..." -ForegroundColor DarkYellow
az k8s-extension show `
  --name azurepolicy `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --query '{name:name, provisioningState:provisioningState, extensionType:extensionType}' `
  -o table

# --- 2. Get cluster resource ID ---
$clusterId = az connectedk8s show `
  --name $clusterName `
  --resource-group $resourceGroup `
  --query id -o tsv

# --- 3. Assign policies ---
Write-Host ""
Write-Host "📜 Assigning Azure Policies..." -ForegroundColor Yellow

# Policy 1: No privileged containers
Write-Host ""
Write-Host "  📌 Policy: Do not allow privileged containers" -ForegroundColor White
az policy assignment create `
  --name "no-privileged-containers" `
  --display-name "[Arc Workshop] Do not allow privileged containers" `
  --policy "95edb821-ddaf-4404-9ab7-b7b2c97b44e7" `
  --scope $clusterId `
  --params '{"effect": {"value": "Deny"}}' 2>$null

# Policy 2: Require environment label
Write-Host ""
Write-Host "  📌 Policy: Require 'environment' label" -ForegroundColor White
az policy assignment create `
  --name "require-env-label" `
  --display-name "[Arc Workshop] Pods must have environment label" `
  --policy "677528de-5c0a-48af-b786-ec2f1ae0f342" `
  --scope $clusterId `
  --params '{"effect": {"value": "Deny"}, "labelsList": {"value": ["environment"]}}' 2>$null

# Policy 3: Allowed registries
Write-Host ""
Write-Host "  📌 Policy: Only allow trusted registries" -ForegroundColor White
az policy assignment create `
  --name "allowed-registries" `
  --display-name "[Arc Workshop] Only allow trusted registries" `
  --policy "febd0533-8e55-448f-b837-bd0e06f16469" `
  --scope $clusterId `
  --params '{"effect": {"value": "Deny"}, "allowedContainerImagesRegex": {"value": "^(docker\\.io|mcr\\.microsoft\\.com|ghcr\\.io)/.*$"}}' 2>$null

Write-Host ""
Write-Host "============================================"                                     -ForegroundColor Cyan
Write-Host "  ✅ Azure Policy configured!"                                                    -ForegroundColor Green
Write-Host "  Policies: No privileged, require labels, trusted registries"                     -ForegroundColor Cyan
Write-Host "  🎯 Demo: kubectl apply -f k8s\privileged-pod.yaml (will fail!)"                 -ForegroundColor DarkYellow
Write-Host "============================================"                                     -ForegroundColor Cyan
