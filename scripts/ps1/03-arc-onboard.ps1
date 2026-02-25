# ============================================================================
# Script 03 - Azure Arc Onboarding
# Connects the K3s cluster to Azure Arc
# Run this ON THE VM via SSH (this script handles the SSH connection)
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Azure Arc - Cluster Onboarding"           -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Configuration ---
$resourceGroup = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-arcworkshop" }
$clusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }
$location = if ($env:LOCATION) { $env:LOCATION }       else { "westeurope" }

$vmIp = $env:VM_PUBLIC_IP
if (-not $vmIp) {
    # Try to get IP from Azure
    $vmName = $env:VM_NAME
    if ($vmName) { $vmIp = (az vm show -g $resourceGroup -n $vmName --show-details --query publicIps -o tsv 2>$null) }
}
if (-not $vmIp) { $vmIp = Read-Host "Enter VM Public IP" }
$vmUser = "azureuser"

Write-Host ""
Write-Host "[INFO] Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Cluster Name:   $clusterName"
Write-Host "  Location:       $location"
Write-Host "  VM:             $vmUser@$vmIp"

# --- SSH into VM and run onboarding ---
Write-Host ""
Write-Host "[LINK] Connecting to VM and onboarding to Azure Arc..." -ForegroundColor Yellow
Write-Host "  You will need to complete device code login on the VM."
Write-Host ""

$sshTarget = "${vmUser}@${vmIp}"
$sshCommand = @'
set -e

# Install Azure CLI if not present
if ! command -v az &>/dev/null; then
  echo '[INSTALL] Installing Azure CLI...'
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Login
echo '[KEY] Login to Azure (device code)...'
az login --use-device-code

# Install extensions
az extension add --name connectedk8s --yes 2>/dev/null || az extension update --name connectedk8s
az extension add --name k8s-configuration --yes 2>/dev/null || az extension update --name k8s-configuration
az extension add --name k8s-extension --yes 2>/dev/null || az extension update --name k8s-extension

# Set kubeconfig
export KUBECONFIG=~/.kube/config
'@

# Build the arc connect command with PS variables injected
$arcConnectCommand = @"
# Connect to Arc
echo '[LINK] Connecting cluster to Azure Arc...'
az connectedk8s connect \
  --name "$clusterName" \
  --resource-group "$resourceGroup" \
  --location "$location"

echo ''
echo '--- Arc Agent Status ---'
az connectedk8s show \
  --name "$clusterName" \
  --resource-group "$resourceGroup" \
  -o table

echo ''
echo '--- Arc Agent Pods ---'
kubectl get pods -n azure-arc

echo ''
echo '[CONNECT] Enabling Cluster Connect feature...'
echo '  (allows kubectl access via Azure Arc - no VPN/SSH needed)'
az connectedk8s enable-features \
  --name "$clusterName" \
  --resource-group "$resourceGroup" \
  --features cluster-connect
echo '[OK] Cluster Connect enabled'

echo ''
echo '[KEY] Configuring Kubernetes RBAC for Cluster Connect...'
AZURE_USER=$(az ad signed-in-user show --query userPrincipalName -o tsv)
echo "  Granting cluster-admin to: $AZURE_USER"
kubectl create clusterrolebinding arc-admin-binding \
  --clusterrole=cluster-admin \
  --user="$AZURE_USER" 2>/dev/null \
  || echo '  (binding already exists)'
echo '[OK] RBAC configured'

echo ''
echo '[OK] Cluster connected to Azure Arc!'
"@

# Strip Windows carriage returns to avoid \r errors on Linux
$sshCommand = $sshCommand -replace "`r", ""
$arcConnectCommand = $arcConnectCommand -replace "`r", ""

ssh -o StrictHostKeyChecking=no $sshTarget ($sshCommand + "`n" + $arcConnectCommand)

Write-Host ""
Write-Host "============================================"                            -ForegroundColor Cyan
Write-Host "  [OK] Arc onboarding complete!"                                           -ForegroundColor Green
Write-Host "  View in Portal: Arc > Kubernetes clusters"                              -ForegroundColor Cyan
Write-Host "  Next: Run 04-deploy-container.ps1"                                     -ForegroundColor Cyan
Write-Host "============================================"                            -ForegroundColor Cyan
# ============================================================================
# Script 03 - Azure Arc Onboarding
# Connects the K3s cluster to Azure Arc
# Run this ON THE VM via SSH (this script handles the SSH connection)
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Azure Arc - Cluster Onboarding"           -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Configuration ---
$resourceGroup = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-arcworkshop" }
$clusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }
$location = if ($env:LOCATION) { $env:LOCATION }       else { "westeurope" }

$vmIp = (azd env get-value VM_PUBLIC_IP 2>$null)
if (-not $vmIp) { $vmIp = Read-Host "Enter VM Public IP" }
$vmUser = "azureuser"

Write-Host ""
Write-Host "📋 Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Cluster Name:   $clusterName"
Write-Host "  Location:       $location"
Write-Host "  VM:             $vmUser@$vmIp"

# --- SSH into VM and run onboarding ---
Write-Host ""
Write-Host "🔗 Connecting to VM and onboarding to Azure Arc..." -ForegroundColor Yellow
Write-Host "  You will need to complete device code login on the VM."
Write-Host ""

ssh -o StrictHostKeyChecking=no "${vmUser}@${vmIp}" @"
set -e

# Install Azure CLI if not present
if ! command -v az &>/dev/null; then
  echo '📦 Installing Azure CLI...'
  curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
fi

# Login
echo '🔐 Login to Azure (device code)...'
az login --use-device-code

# Install extensions
az extension add --name connectedk8s --yes 2>/dev/null || az extension update --name connectedk8s
az extension add --name k8s-configuration --yes 2>/dev/null || az extension update --name k8s-configuration
az extension add --name k8s-extension --yes 2>/dev/null || az extension update --name k8s-extension

# Set kubeconfig
export KUBECONFIG=~/.kube/config

# Connect to Arc
echo '🔗 Connecting cluster to Azure Arc...'
az connectedk8s connect \
  --name "$clusterName" \
  --resource-group "$resourceGroup" \
  --location "$location"

echo ''
echo '--- Arc Agent Status ---'
az connectedk8s show \
  --name "$clusterName" \
  --resource-group "$resourceGroup" \
  -o table

echo ''
echo '--- Arc Agent Pods ---'
kubectl get pods -n azure-arc

echo ''
echo '✅ Cluster connected to Azure Arc!'
"@

Write-Host ""
Write-Host "============================================"                            -ForegroundColor Cyan
Write-Host "  ✅ Arc onboarding complete!"                                           -ForegroundColor Green
Write-Host "  View in Portal: Arc > Kubernetes clusters"                              -ForegroundColor Cyan
Write-Host "  Next: Run 04-deploy-container.ps1"                                     -ForegroundColor Cyan
Write-Host "============================================"                            -ForegroundColor Cyan
