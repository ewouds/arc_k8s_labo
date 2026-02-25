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
$clusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }

Write-Host ""
Write-Host "[INFO] Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Cluster Name:   $clusterName"

# --- 1. Install Azure Policy extension ---
Write-Host ""
Write-Host "[INSTALL] Installing Azure Policy extension (OPA Gatekeeper)..." -ForegroundColor Yellow

az k8s-extension create `
  --name azurepolicy `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --extension-type Microsoft.PolicyInsights

Write-Host ""
Write-Host "[WAIT] Checking extension status..." -ForegroundColor DarkYellow
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
Write-Host "[POLICY] Assigning Azure Policies..." -ForegroundColor Yellow

# Policy 1: No privileged containers
Write-Host ""
Write-Host "  [PIN] Policy: Do not allow privileged containers" -ForegroundColor White
az policy assignment create `
  --name "no-privileged-containers" `
  --display-name "[Arc Workshop] Do not allow privileged containers" `
  --policy "95edb821-ddaf-4404-9732-666045e056b4" `
  --scope $clusterId `
  --params '{\"effect\":{\"value\":\"Deny\"}}'
if ($LASTEXITCODE -ne 0) { Write-Host "  [WARN]  Policy may already be assigned or failed" -ForegroundColor DarkYellow }

# Policy 2: Require environment label
Write-Host ""
Write-Host "  [PIN] Policy: Require 'environment' label" -ForegroundColor White
az policy assignment create `
  --name "require-env-label" `
  --display-name "[Arc Workshop] Pods must have environment label" `
  --policy "46592696-4c7b-4bf3-9e45-6c2763bdc0a6" `
  --scope $clusterId `
  --params '{\"effect\":{\"value\":\"Deny\"},\"labelsList\":{\"value\":[\"environment\"]}}'
if ($LASTEXITCODE -ne 0) { Write-Host "  [WARN]  Policy may already be assigned or failed" -ForegroundColor DarkYellow }

# Policy 3: Allowed registries
Write-Host ""
Write-Host "  [PIN] Policy: Only allow trusted registries" -ForegroundColor White
az policy assignment create `
  --name "allowed-registries" `
  --display-name "[Arc Workshop] Only allow trusted registries" `
  --policy "febd0533-8e55-448f-b837-bd0e06f16469" `
  --scope $clusterId `
  --params '{\"effect\":{\"value\":\"Deny\"},\"allowedContainerImagesRegex\":{\"value\":\"^(docker\\\\.io|mcr\\\\.microsoft\\\\.com|ghcr\\\\.io)/.*$\"}}'
if ($LASTEXITCODE -ne 0) { Write-Host "  [WARN]  Policy may already be assigned or failed" -ForegroundColor DarkYellow }

# --- 4. Verify policy assignments ---
Write-Host ""
Write-Host "[CHECK] Verifying policy assignments..." -ForegroundColor Yellow
az policy assignment list `
  --scope $clusterId `
  --query "[].{name:name, displayName:displayName}" `
  -o table

Write-Host ""
Write-Host "============================================"                                     -ForegroundColor Cyan
Write-Host "  [OK] Azure Policy configured!"                                                    -ForegroundColor Green
Write-Host "  Policies: No privileged, require labels, trusted registries"                     -ForegroundColor Cyan
Write-Host "============================================"                                     -ForegroundColor Cyan

# --- 5. Validation note ---
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  [WARN]  Important: Policy sync delay"              -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Policies need 15-30 min to sync to the cluster via Gatekeeper." -ForegroundColor White
Write-Host "  Continue with the next sections and come back to validate." -ForegroundColor White
Write-Host ""
Write-Host "  To check if policies are ready:" -ForegroundColor White
Write-Host "    kubectl get constraints" -ForegroundColor Green
Write-Host "    kubectl get constrainttemplates" -ForegroundColor Green
Write-Host ""
Write-Host "  To test enforcement:" -ForegroundColor White
Write-Host "    kubectl apply -f k8s\privileged-pod.yaml" -ForegroundColor Green
Write-Host "    (should fail with: Forbidden / admission webhook denied)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  To check compliance in Azure Portal:" -ForegroundColor White
Write-Host "    Arc cluster > Policies" -ForegroundColor Green
Write-Host ""
Write-Host "  Next: Run 06-defender.ps1"                                                    -ForegroundColor Cyan
Write-Host "============================================"                                     -ForegroundColor Cyan
