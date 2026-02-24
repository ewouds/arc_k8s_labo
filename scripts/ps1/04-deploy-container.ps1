# ============================================================================
# Script 04 - Deploy Containers via Azure Arc (3 ways)
# Run from your LOCAL machine (PowerShell)
#
# This script demonstrates 3 ways to deploy workloads to an Arc-connected
# cluster — showcasing Arc's flexibility:
#   1. CLI via Cluster Connect (az connectedk8s proxy + kubectl)
#   2. Azure Portal (paste YAML in the portal UI)
#   3. GitHub Copilot (AI-generated YAML — bonus!)
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
}
else {
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
# Step 3 (BONUS): Deploy a 3rd container using GitHub Copilot
#   Show attendees how GitHub Copilot can generate Kubernetes manifests
#   and deploy them — AI-assisted operations on Arc-connected clusters.
# ============================================================================
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host "  🎁 BONUS: Deploy 3rd container via GitHub Copilot" -ForegroundColor White
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
Write-Host ""
Write-Host "🤖 Use GitHub Copilot to generate AND deploy a Kubernetes workload!" -ForegroundColor Yellow
Write-Host ""
Write-Host "   How to do it:" -ForegroundColor White
Write-Host "   ─────────────" -ForegroundColor DarkGray
Write-Host "   1. Open GitHub Copilot Chat in VS Code (Ctrl+Shift+I)" -ForegroundColor White
Write-Host "   2. Type a prompt like one of these:" -ForegroundColor White
Write-Host ""
Write-Host '      "Create a Kubernetes deployment YAML for a container called' -ForegroundColor DarkCyan
Write-Host '       copilot-demo in the demo namespace, using the nginx:alpine' -ForegroundColor DarkCyan
Write-Host '       image with 1 replica. Include resource limits and a service.' -ForegroundColor DarkCyan
Write-Host '       Save it at k8s/copilot-demo.yaml"' -ForegroundColor DarkCyan
Write-Host ""
Write-Host "   3. Review the generated YAML — Copilot creates it for you!" -ForegroundColor White
Write-Host "   4. Apply it with:" -ForegroundColor White
Write-Host '      kubectl apply -f k8s/copilot-demo.yaml' -ForegroundColor Green
Write-Host ""
Write-Host "   💡 Tip: You can also ask Copilot directly:" -ForegroundColor Magenta
Write-Host '      @terminal kubectl apply the copilot-demo.yaml' -ForegroundColor DarkCyan
Write-Host '      or ask: "Deploy this YAML to my cluster"' -ForegroundColor DarkCyan
Write-Host ""
Write-Host "   Why this matters:" -ForegroundColor White
Write-Host "   • No need to memorize YAML syntax" -ForegroundColor DarkGray
Write-Host "   • Copilot follows best practices (resource limits, labels, probes)" -ForegroundColor DarkGray
Write-Host "   • Works seamlessly with Arc Cluster Connect — same kubectl" -ForegroundColor DarkGray
Write-Host ""
Write-Host "⏸️  Use Copilot to generate & deploy a container, then press Enter to verify..." -ForegroundColor Magenta
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
Write-Host "  3. Copilot     — AI-generated YAML via GitHub Copilot (copilot-demo)"      -ForegroundColor Green
Write-Host "  View in Portal: Arc cluster > Kubernetes resources > Workloads"             -ForegroundColor Cyan
Write-Host "============================================"                                -ForegroundColor Cyan
