# ============================================================================
# Script 04 - Deploy Containers via Azure Arc (3 ways)
# Run from your LOCAL machine (PowerShell)
#
# This script demonstrates 3 ways to deploy workloads to an Arc-connected
# cluster — showcasing Arc's flexibility:
#   1. CLI via Cluster Connect (az connectedk8s proxy + kubectl)
#   2. Azure Portal (paste YAML in the portal UI)
#   3. Microsoft Copilot in Azure (AI-assisted — bonus!)
#
# No VPN, no SSH, no direct network access needed — that's the power of Arc.
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Deploy Container via Azure Arc"           -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Configuration ---
$resourceGroup = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-arcworkshop" }
$clusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }

# Resolve path to k8s manifests (relative to project root)
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$manifestPath = Join-Path $projectRoot "k8s\demo-app.yaml"

Write-Host ""
Write-Host "📋 Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Cluster Name:   $clusterName"
Write-Host "  Manifest:       $manifestPath"

# ============================================================================
# Cluster Connect (az connectedk8s proxy)
#   Opens a tunnel via Azure Arc to the cluster — no direct network access
#   needed. All traffic flows through Azure as a reverse proxy.
# ============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Cluster Connect — deploying via Azure Arc proxy" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

Write-Host ""
Write-Host "🔌 Checking Cluster Connect..." -ForegroundColor Yellow

# Check if a proxy is already running and kubectl works
$proxyJob = $null
$proxyAlreadyRunning = $false
$null = kubectl get nodes 2>&1
if ($LASTEXITCODE -eq 0) {
    $proxyAlreadyRunning = $true
    Write-Host "  ✅ Existing proxy detected — reusing connection" -ForegroundColor Green
} else {
    Write-Host "  Starting Cluster Connect proxy..." -ForegroundColor Yellow
    $proxyJob = Start-Job -ScriptBlock {
        az connectedk8s proxy -n $using:clusterName -g $using:resourceGroup 2>&1
    }

    # Give the proxy time to establish the tunnel
    Write-Host "   Waiting for proxy tunnel to establish..." -ForegroundColor DarkYellow
    Start-Sleep -Seconds 15

    # Verify the tunnel is working
    $null = kubectl get nodes 2>&1
    if ($LASTEXITCODE -ne 0) {
        $jobOutput = Receive-Job -Job $proxyJob 2>&1 | Out-String
        Stop-Job -Job $proxyJob -ErrorAction SilentlyContinue
        Remove-Job -Job $proxyJob -Force -ErrorAction SilentlyContinue
        Write-Host "  Proxy output: $jobOutput" -ForegroundColor Red
        throw "Cluster Connect proxy failed. Ensure the cluster is Arc-connected and try again."
    }
}

Write-Host "✅ Cluster Connect active — kubectl is working via Azure Arc" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 Deploying application..." -ForegroundColor Yellow
kubectl apply -f $manifestPath

Write-Host ""
Write-Host "⏳ Waiting for pods to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app=nginx-demo -n demo --timeout=120s

Write-Host ""
Write-Host "--- Demo Application Status ---" -ForegroundColor Cyan
kubectl get all -n demo

# Clean up proxy job (only if we started one)
if ($proxyJob) {
    Stop-Job -Job $proxyJob -ErrorAction SilentlyContinue
    Remove-Job -Job $proxyJob -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "============================================"                                -ForegroundColor Cyan
Write-Host "  ✅ Application 1 (nginx-demo) deployed via Cluster Connect!"                -ForegroundColor Green
Write-Host "  No SSH, no VPN — just Azure Arc."                                          -ForegroundColor Green
Write-Host "============================================"                                -ForegroundColor Cyan

# ============================================================================
# Step 2: Deploy second container via Azure Portal (manual)
#   Demonstrate that you can deploy workloads directly from the Azure Portal
#   by pasting YAML — no CLI required.
# ============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  Deploy 2nd container via Azure Portal"     -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "🌐 Now open the Azure Portal and deploy a second container manually:" -ForegroundColor Yellow
Write-Host "   1. Go to: Arc cluster ($clusterName) > Kubernetes resources > Workloads" -ForegroundColor White
Write-Host "   2. Click '+ Create' > 'Apply with YAML'" -ForegroundColor White
Write-Host "   3. Paste the contents of: k8s/hello-arc.yaml" -ForegroundColor White
Write-Host "   4. Click 'Add' and wait for the pod to be Running" -ForegroundColor White
Write-Host ""

$helloArcPath = Join-Path $projectRoot "k8s\hello-arc.yaml"
Write-Host "📄 YAML to paste (also available at $helloArcPath):" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray
Get-Content $helloArcPath | Write-Host
Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray

Write-Host ""
Write-Host "⏸️  Deploy the YAML above via the Azure Portal, then press Enter to verify..." -ForegroundColor Magenta
Read-Host

# Verify both deployments
Write-Host "🔍 Verifying both deployments..." -ForegroundColor Yellow
kubectl get deployments -n demo
kubectl get pods -n demo

Write-Host ""
Write-Host "============================================"                                -ForegroundColor Cyan
Write-Host "  ✅ Two containers running on-prem via Azure Arc!"                           -ForegroundColor Green
Write-Host "  - nginx-demo  (deployed via CLI / Cluster Connect)"                        -ForegroundColor Green
Write-Host "  - hello-arc   (deployed via Azure Portal)"                                 -ForegroundColor Green
Write-Host "============================================"                                -ForegroundColor Cyan

# ============================================================================
# Step 3 (BONUS): Deploy a 3rd container using Microsoft Copilot in Azure
#   Show attendees how Copilot in Azure can help deploy workloads
#   directly from the Azure Portal — AI-assisted operations.
# ============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  🎁 BONUS: Deploy 3rd container via Microsoft Copilot in Azure" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "🤖 Use Microsoft Copilot in Azure to deploy a Kubernetes workload!" -ForegroundColor Yellow
Write-Host ""
Write-Host "   How to do it:" -ForegroundColor White
Write-Host "   ─────────────" -ForegroundColor DarkGray
Write-Host "   1. In the Azure Portal, go to:" -ForegroundColor White
Write-Host "      Arc cluster ($clusterName) > Kubernetes resources > Workloads" -ForegroundColor White
Write-Host "   2. Click '+ Create' (top left) > 'Ask Copilot'" -ForegroundColor White
Write-Host "   3. Type a prompt like:" -ForegroundColor White
Write-Host ""
Write-Host '      "Deploy an nginx:alpine container called copilot-demo' -ForegroundColor DarkCyan
Write-Host '       in the demo namespace with 1 replica"' -ForegroundColor DarkCyan
Write-Host ""
Write-Host "   4. Copilot will generate the YAML for you" -ForegroundColor White
Write-Host "   5. Review and confirm the deployment" -ForegroundColor White
Write-Host ""
Write-Host "   💡 Other prompts you can try:" -ForegroundColor Magenta
Write-Host '      "Show me the workloads on my Arc cluster arc-k3s-cluster"' -ForegroundColor DarkCyan
Write-Host '      "How do I deploy a container to my Arc-connected cluster?"' -ForegroundColor DarkCyan
Write-Host '      "Create a Kubernetes deployment YAML for nginx:alpine"' -ForegroundColor DarkCyan
Write-Host ""
Write-Host "   Why this matters:" -ForegroundColor White
Write-Host "   • Natural language — no need to memorize commands or YAML" -ForegroundColor DarkGray
Write-Host "   • Copilot is context-aware (knows your subscriptions & clusters)" -ForegroundColor DarkGray
Write-Host "   • Works directly in the Azure Portal — no extra tools needed" -ForegroundColor DarkGray
Write-Host ""
Write-Host "⏸️  Use Copilot in Azure to deploy a container, then press Enter to verify..." -ForegroundColor Magenta
Read-Host

# Verify all deployments
Write-Host "🔍 Verifying all deployments in the demo namespace..." -ForegroundColor Yellow
Write-Host ""
Write-Host "--- Deployments ---" -ForegroundColor Cyan
kubectl get deployments -n demo
Write-Host ""
Write-Host "--- Pods ---" -ForegroundColor Cyan
kubectl get pods -n demo
Write-Host ""
Write-Host "--- Services ---" -ForegroundColor Cyan
kubectl get services -n demo

Write-Host ""
Write-Host "============================================"                                -ForegroundColor Cyan
Write-Host "  ✅ Three ways to deploy on Arc-connected clusters!"                        -ForegroundColor Green
Write-Host "  1. CLI         — kubectl via Cluster Connect (nginx-demo)"                 -ForegroundColor Green
Write-Host "  2. Portal      — YAML via Azure Portal UI (hello-arc)"                     -ForegroundColor Green
Write-Host "  3. Copilot     — AI-assisted deploy via Microsoft Copilot in Azure"       -ForegroundColor Green
Write-Host "  View in Portal: Arc cluster > Kubernetes resources > Workloads"             -ForegroundColor Cyan
Write-Host "============================================"                                -ForegroundColor Cyan
