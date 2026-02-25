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
$clusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }
$workspaceId = $env:LOG_ANALYTICS_WORKSPACE_ID
if (-not $workspaceId) {
  # Try to find workspace in the resource group
  $workspaceId = (az monitor log-analytics workspace list -g $resourceGroup --query "[0].id" -o tsv 2>$null)
}
if (-not $workspaceId) { $workspaceId = Read-Host "Enter Log Analytics Workspace Resource ID" }

Write-Host ""
Write-Host "[INFO] Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Cluster Name:   $clusterName"
Write-Host "  Workspace:      $workspaceId"

# --- 1. Enable Defender for Containers plan ---
Write-Host ""
Write-Host "[SHIELD] Enabling Defender for Containers plan..." -ForegroundColor Yellow
az security pricing create --name Containers --tier Standard 2>$null
Write-Host "  [OK] Defender plan enabled" -ForegroundColor Green

# --- 2. Install Defender extension ---
Write-Host ""
Write-Host "[INSTALL] Installing Defender extension on Arc cluster..." -ForegroundColor Yellow
Write-Host "  (This can take 10-15 min on small VMs - using --no-wait)" -ForegroundColor DarkGray

# Delete any previous failed installation first
$existing = az k8s-extension show `
  --name microsoft.azuredefender.kubernetes `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --query provisioningState -o tsv 2>$null
if ($existing -eq "Failed") {
  Write-Host "  [DELETE]  Removing previous failed installation..." -ForegroundColor DarkYellow
  az k8s-extension delete `
    --name microsoft.azuredefender.kubernetes `
    --cluster-name $clusterName `
    --resource-group $resourceGroup `
    --cluster-type connectedClusters `
    --yes 2>$null
  Start-Sleep -Seconds 10
}

az k8s-extension create `
  --name microsoft.azuredefender.kubernetes `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --extension-type microsoft.azuredefender.kubernetes `
  --configuration-settings "logAnalyticsWorkspaceResourceID=$workspaceId" `
  --no-wait 2>$null

# Poll for status (up to 10 minutes)
Write-Host ""
Write-Host "[WAIT] Waiting for extension to provision (checking every 30s, max 10 min)..." -ForegroundColor DarkYellow
$maxAttempts = 20
$attempt = 0
$state = "Creating"
while ($attempt -lt $maxAttempts -and $state -notin @("Succeeded", "Failed")) {
  Start-Sleep -Seconds 30
  $attempt++
  $state = az k8s-extension show `
    --name microsoft.azuredefender.kubernetes `
    --cluster-name $clusterName `
    --resource-group $resourceGroup `
    --cluster-type connectedClusters `
    --query provisioningState -o tsv 2>$null
  Write-Host "  [$attempt/$maxAttempts] State: $state" -ForegroundColor DarkGray
}

az k8s-extension show `
  --name microsoft.azuredefender.kubernetes `
  --cluster-name $clusterName `
  --resource-group $resourceGroup `
  --cluster-type connectedClusters `
  --query '{name:name, provisioningState:provisioningState, extensionType:extensionType}' `
  -o table

if ($state -eq "Failed") {
  Write-Host ""
  Write-Host "  [WARN]  Extension provisioning failed (common on small VMs)." -ForegroundColor DarkYellow
  Write-Host "  The Defender Helm chart requires significant resources." -ForegroundColor DarkGray
  Write-Host "  You can retry later or resize the VM to Standard_D4s_v3." -ForegroundColor DarkGray
  Write-Host "  For the workshop demo, the Defender plan is still enabled" -ForegroundColor DarkGray
  Write-Host "  at the subscription level - you can show it in the Portal." -ForegroundColor DarkGray
}
elseif ($state -eq "Succeeded") {
  Write-Host "  [OK] Extension installed successfully" -ForegroundColor Green
}
else {
  Write-Host ""
  Write-Host "  [WAIT] Extension still provisioning after 10 min." -ForegroundColor DarkYellow
  Write-Host "  Check status later with:" -ForegroundColor DarkGray
  Write-Host "  az k8s-extension show --name microsoft.azuredefender.kubernetes --cluster-name $clusterName --resource-group $resourceGroup --cluster-type connectedClusters -o table" -ForegroundColor Green
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  What Defender provides:" -ForegroundColor White
Write-Host "  [CHECK] Runtime threat detection" 
Write-Host "  [INSTALL] Image vulnerability scanning"
Write-Host "  [LOCK] Security recommendations"
Write-Host "  [STATS] View: Defender for Cloud > Workload protections" 
Write-Host "==========================================" -ForegroundColor DarkGray

# --- 3. Verify Defender pods on the cluster ---
Write-Host ""
Write-Host "[CHECK] Verifying Defender pods on the cluster..." -ForegroundColor Yellow

$vmIp = if ($env:VM_IP) { $env:VM_IP } else { "20.240.42.92" }
$vmUser = if ($env:VM_USER) { $env:VM_USER } else { "azureuser" }

ssh ${vmUser}@${vmIp} "KUBECONFIG=~/.kube/config kubectl get pods -n mdc --no-headers 2>/dev/null" 2>$null
$mdcPods = $LASTEXITCODE
if ($mdcPods -ne 0) {
  Write-Host "  [WARN]  No Defender pods found yet (namespace 'mdc' may take a few minutes)" -ForegroundColor DarkYellow
}
else {
  Write-Host "  [OK] Defender sensor pods are running" -ForegroundColor Green
}

# --- 4. Trigger a test security alert ---
Write-Host ""
Write-Host "[TEST] Triggering a test security alert..." -ForegroundColor Yellow
Write-Host "  Running the official Microsoft Defender test alert container" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  [WARN]  If governance policies (Section 5) are active, disable them first:" -ForegroundColor DarkYellow
Write-Host "     .\scripts\ps1\05a-toggle-policies.ps1 disable" -ForegroundColor White
Write-Host "     (Re-enable after the test with: .\scripts\ps1\05a-toggle-policies.ps1 enable)" -ForegroundColor DarkGray
Write-Host ""

ssh ${vmUser}@${vmIp} "KUBECONFIG=~/.kube/config kubectl delete pod defender-test --ignore-not-found 2>/dev/null; KUBECONFIG=~/.kube/config kubectl run defender-test --image=mcr.microsoft.com/aks/security/test-alert --restart=Never --labels=environment=workshop 2>/dev/null"
if ($LASTEXITCODE -eq 0) {
  Write-Host "  [OK] Test alert triggered - will appear in Defender for Cloud within ~30 min" -ForegroundColor Green
}
else {
  Write-Host "  [WARN]  Could not trigger test alert (check SSH connectivity)" -ForegroundColor DarkYellow
}

# --- 5. Portal walkthrough ---
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  [STATS] Portal Demo Walkthrough:" -ForegroundColor White
Write-Host ""
Write-Host "  1. Defender for Cloud > Workload protections > Containers" 
Write-Host "     -> Your Arc cluster is listed with Defender coverage"
Write-Host ""
Write-Host "  2. Defender for Cloud > Security alerts" 
Write-Host "     -> Test alert appears here (~30 min delay)"
Write-Host ""
Write-Host "  3. Defender for Cloud > Recommendations" 
Write-Host "     -> Filter by connectedClusters for hardening tips"
Write-Host ""
Write-Host "  4. Arc cluster > Security (blade)" 
Write-Host "     -> Defender status directly on the Arc resource"
Write-Host "==========================================" -ForegroundColor DarkGray

# --- 6. Cleanup & re-enable policies ---
Write-Host ""
Write-Host "[CLEAN] Cleanup (run after demo):" -ForegroundColor Yellow
Write-Host "  ssh ${vmUser}@${vmIp} `"kubectl delete pod defender-test --ignore-not-found`"" -ForegroundColor DarkGray
Write-Host "  .\scripts\ps1\05a-toggle-policies.ps1 enable" -ForegroundColor DarkGray

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  [OK] Microsoft Defender configured!"        -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Cyan
