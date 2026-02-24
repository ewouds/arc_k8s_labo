# ============================================================================
# Script 09a - (OPTIONAL) Deploy AKS cluster for Inventory comparison
# Run from your LOCAL machine (PowerShell)
#
# This deploys a small AKS cluster so you can demonstrate Azure Resource Graph
# queries that show Arc + AKS clusters side by side.
#
# ⚠️  EXTRA COST: ~€0.10/hour (Standard_B2s node)
#     Run cleanup when done: az group delete --name rg-arcworkshop-aks --yes
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  (Optional) Deploy AKS for Inventory Demo" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Configuration ---
$aksResourceGroup = "rg-arcworkshop-aks"
$aksClusterName   = "aks-workshop-cluster"
$location         = if ($env:AZURE_LOCATION) { $env:AZURE_LOCATION } else { "swedencentral" }

Write-Host ""
Write-Host "📋 Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $aksResourceGroup"
Write-Host "  AKS Cluster:    $aksClusterName"
Write-Host "  Location:       $location"
Write-Host ""
Write-Host "⚠️  This will incur additional Azure costs (~€0.10/hour)" -ForegroundColor DarkYellow
Write-Host "  The AKS cluster uses a single Standard_B2s node" -ForegroundColor DarkGray
Write-Host ""

$confirm = Read-Host "Continue? (y/N)"
if ($confirm -notin @('y', 'Y')) {
    Write-Host "Cancelled." -ForegroundColor DarkYellow
    exit 0
}

# --- 1. Create resource group ---
Write-Host ""
Write-Host "📦 Creating resource group..." -ForegroundColor Yellow
az group create --name $aksResourceGroup --location $location -o none
Write-Host "  ✅ Resource group created" -ForegroundColor Green

# --- 2. Deploy AKS cluster ---
Write-Host ""
Write-Host "🚀 Deploying AKS cluster (this takes ~5 minutes)..." -ForegroundColor Yellow
Write-Host "  Single node, Standard_B2s (minimal cost)" -ForegroundColor DarkGray

az aks create `
  --name $aksClusterName `
  --resource-group $aksResourceGroup `
  --location $location `
  --node-count 1 `
  --node-vm-size Standard_B2s `
  --generate-ssh-keys `
  --tier free `
  --no-wait `
  -o none

# Poll for status
Write-Host ""
Write-Host "⏳ Waiting for AKS cluster to provision..." -ForegroundColor DarkYellow
$maxAttempts = 30
$attempt = 0
$state = "Creating"
while ($attempt -lt $maxAttempts -and $state -notin @("Succeeded", "Failed")) {
    Start-Sleep -Seconds 20
    $attempt++
    $state = az aks show `
      --name $aksClusterName `
      --resource-group $aksResourceGroup `
      --query provisioningState -o tsv 2>$null
    Write-Host "  [$attempt/$maxAttempts] State: $state" -ForegroundColor DarkGray
}

if ($state -eq "Succeeded") {
    Write-Host "  ✅ AKS cluster deployed successfully" -ForegroundColor Green
}
else {
    Write-Host "  ⚠️  AKS cluster still provisioning. Check Azure Portal." -ForegroundColor DarkYellow
}

# --- 3. Deploy a sample workload ---
Write-Host ""
Write-Host "📦 Deploying sample workload to AKS..." -ForegroundColor Yellow

az aks get-credentials --name $aksClusterName --resource-group $aksResourceGroup --overwrite-existing 2>$null

kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f - <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-aks
  namespace: demo
  labels:
    app: hello-aks
    environment: workshop
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-aks
  template:
    metadata:
      labels:
        app: hello-aks
        environment: workshop
    spec:
      containers:
        - name: hello-aks
          image: mcr.microsoft.com/azuredocs/aks-helloworld:v1
          ports:
            - containerPort: 80
          env:
            - name: TITLE
              value: "Hello from AKS! ☁️"
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
EOF

Write-Host "  ✅ Sample workload deployed" -ForegroundColor Green

# --- 4. Show comparison ---
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  🔍 Arc + AKS side by side:" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

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

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Now run script 09 again to see both clusters" -ForegroundColor White
Write-Host "  in the Resource Graph queries!" -ForegroundColor White
Write-Host ""
Write-Host "  ⚠️  Cleanup when done:" -ForegroundColor DarkYellow
Write-Host "  az group delete --name $aksResourceGroup --yes" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ AKS cluster ready for inventory demo!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
