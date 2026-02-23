# ============================================================================
# Script 04 - Deploy Container from Azure to Arc-connected Cluster
# Run from your LOCAL machine (PowerShell)
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Deploy Container via Azure Arc"           -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Configuration ---
$resourceGroup = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-arcworkshop" }
$clusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }
$vmIp = (azd env get-value VM_PUBLIC_IP 2>$null)
if (-not $vmIp) { $vmIp = Read-Host "Enter VM Public IP" }
$vmUser = "azureuser"

Write-Host ""
Write-Host "📋 Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Cluster Name:   $clusterName"
Write-Host "  VM:             $vmUser@$vmIp"

# ============================================================================
# METHOD 1: Cluster Connect (az connectedk8s proxy)
# ============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Method 1: Cluster Connect" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Start proxy in a separate terminal:" -ForegroundColor DarkYellow
Write-Host "    az connectedk8s proxy -n $clusterName -g $resourceGroup"
Write-Host ""
Write-Host "  Then use kubectl locally:"
Write-Host "    kubectl get nodes"
Write-Host "    kubectl apply -f k8s\demo-app.yaml"

# ============================================================================
# METHOD 2: Deploy via SSH
# ============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Method 2: Deploy via SSH" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""

# Resolve path to k8s manifests (relative to project root)
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$manifestPath = Join-Path $projectRoot "k8s\demo-app.yaml"

Write-Host "📦 Copying manifest to VM..." -ForegroundColor Yellow
scp -o StrictHostKeyChecking=no $manifestPath "${vmUser}@${vmIp}:~/demo-app.yaml"

Write-Host "🚀 Deploying application on the cluster..." -ForegroundColor Yellow
ssh -o StrictHostKeyChecking=no "${vmUser}@${vmIp}" @"
export KUBECONFIG=~/.kube/config
kubectl apply -f ~/demo-app.yaml

echo ''
echo '⏳ Waiting for pods...'
kubectl wait --for=condition=ready pod -l app=nginx-demo -n demo --timeout=120s

echo ''
echo '--- Demo Application Status ---'
kubectl get all -n demo
"@

Write-Host ""
Write-Host "============================================"                                -ForegroundColor Cyan
Write-Host "  ✅ Application deployed!"                                                  -ForegroundColor Green
Write-Host "  View in Portal: Arc cluster > Kubernetes resources > Workloads"             -ForegroundColor Cyan
Write-Host "============================================"                                -ForegroundColor Cyan
