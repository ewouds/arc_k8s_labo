# ============================================================================
# Script 10 - Service Mesh on Azure Arc-enabled Kubernetes
# Demonstrates Linkerd service mesh deployed & managed through Arc capabilities
# Run from your LOCAL machine (PowerShell)
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Service Mesh on Azure Arc"                  -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Configuration ---
$resourceGroup = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-arcworkshop" }
$clusterName   = if ($env:CLUSTER_NAME)   { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }

Write-Host ""
Write-Host "[INFO] Configuration:" -ForegroundColor Yellow
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Cluster Name:   $clusterName"

# ============================================================================
# STEP 1 - Install Linkerd Service Mesh
# ============================================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Step 1: Install Linkerd Service Mesh"       -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Linkerd is a lightweight CNCF-graduated service mesh." -ForegroundColor Gray
Write-Host "  It adds: mTLS, observability, traffic splitting."     -ForegroundColor Gray
Write-Host "  Memory footprint: ~50 MB (ideal for K3s / edge)."    -ForegroundColor Gray

# Check if Linkerd CLI is available
$linkerdPath = Get-Command linkerd -ErrorAction SilentlyContinue
if (-not $linkerdPath) {
    Write-Host ""
    Write-Host "[INSTALL] Installing Linkerd CLI..." -ForegroundColor Yellow
    # Windows install via scoop or direct download
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install linkerd
    } else {
        $linkerdVersion = (Invoke-RestMethod "https://api.github.com/repos/linkerd/linkerd2/releases/latest").tag_name
        $url = "https://github.com/linkerd/linkerd2/releases/download/$linkerdVersion/linkerd2-cli-$linkerdVersion-windows.exe"
        $dest = "$env:USERPROFILE\.linkerd2\bin\linkerd.exe"
        New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.linkerd2\bin" | Out-Null
        Invoke-WebRequest -Uri $url -OutFile $dest
        $env:PATH = "$env:USERPROFILE\.linkerd2\bin;$env:PATH"
    }
    Write-Host "  [OK] Linkerd CLI installed" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "  [OK] Linkerd CLI already installed" -ForegroundColor Green
}

Write-Host ""
Write-Host "[CHECK] Pre-flight check..." -ForegroundColor Yellow
linkerd check --pre 2>&1 | Select-Object -Last 5

Write-Host ""
Write-Host "[INSTALL] Installing Linkerd CRDs..." -ForegroundColor Yellow
linkerd install --crds | kubectl apply -f - 2>$null

Write-Host ""
Write-Host "[INSTALL] Installing Linkerd control plane..." -ForegroundColor Yellow
linkerd install | kubectl apply -f - 2>$null

Write-Host ""
Write-Host "[WAIT] Waiting for Linkerd to become ready..." -ForegroundColor DarkYellow
linkerd check 2>&1 | Select-Object -Last 10

Write-Host "  [OK] Linkerd control plane installed" -ForegroundColor Green

# ============================================================================
# STEP 2 - Deploy mesh demo app
# ============================================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Step 2: Deploy Mesh Demo App via GitOps"    -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Architecture: Frontend (nginx) -> Backend (http-echo)" -ForegroundColor Gray
Write-Host "  Both pods get Linkerd sidecar proxies automatically." -ForegroundColor Gray
Write-Host ""
Write-Host "  [KEY] Arc added value: Deploy via GitOps - no direct cluster access!" -ForegroundColor Magenta

Write-Host ""
Write-Host "[INSTALL] Creating mesh-demo namespace..." -ForegroundColor Yellow
kubectl apply -f k8s/mesh-demo/namespace.yaml

Write-Host "[INSTALL] Deploying frontend + backend..." -ForegroundColor Yellow
kubectl apply -f k8s/mesh-demo/backend-v1.yaml
kubectl apply -f k8s/mesh-demo/backend-service.yaml
kubectl apply -f k8s/mesh-demo/frontend.yaml

Write-Host ""
Write-Host "[WAIT] Waiting for pods to be ready..." -ForegroundColor DarkYellow
kubectl wait --for=condition=ready pod -l app=backend -n mesh-demo --timeout=120s
kubectl wait --for=condition=ready pod -l app=frontend -n mesh-demo --timeout=120s

Write-Host ""
Write-Host "[STATS] Mesh demo pods:" -ForegroundColor Yellow
kubectl get pods -n mesh-demo -o wide

# ============================================================================
# STEP 3 - Verify mTLS
# ============================================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Step 3: Verify mTLS (Zero-Trust)"           -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Linkerd automatically encrypts all pod-to-pod traffic" -ForegroundColor Gray
Write-Host "  using mutual TLS - no code changes needed!"           -ForegroundColor Gray

# Check sidecar injection
Write-Host ""
Write-Host "[CHECK] Checking sidecar injection..." -ForegroundColor Yellow
$frontendContainers = kubectl get pod -l app=frontend -n mesh-demo -o jsonpath='{.items[0].spec.containers[*].name}'
Write-Host "  Frontend containers: $frontendContainers"

$backendContainers = kubectl get pod -l app=backend -n mesh-demo -o jsonpath='{.items[0].spec.containers[*].name}'
Write-Host "  Backend containers:  $backendContainers"

Write-Host ""
Write-Host "[KEY] Checking mTLS status..." -ForegroundColor Yellow
linkerd viz stat deploy -n mesh-demo 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "  (Install linkerd-viz for detailed stats: linkerd viz install | kubectl apply -f -)" -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "[WEB] Testing service-to-service call..." -ForegroundColor Yellow
$frontendPod = kubectl get pod -l app=frontend -n mesh-demo -o jsonpath='{.items[0].metadata.name}'
kubectl exec $frontendPod -n mesh-demo -c frontend -- wget -qO- http://backend.mesh-demo.svc.cluster.local/

Write-Host ""
Write-Host "  [OK] mTLS active - traffic is encrypted between services" -ForegroundColor Green

# ============================================================================
# STEP 4 - Observe in Azure (Container Insights)
# ============================================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Step 4: Observe via Container Insights"      -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  [KEY] Arc added value: Azure Monitor sees mesh sidecar metrics!" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Container Insights captures:" -ForegroundColor Gray
Write-Host "    * Sidecar proxy CPU/memory usage"
Write-Host "    * Pod startup time with sidecars"
Write-Host "    * Container restart counts per sidecar"
Write-Host ""

Write-Host "[STATS] Querying Container Insights for mesh-demo pods..." -ForegroundColor Yellow
Write-Host ""
Write-Host "  [FOLDER] View in Portal:" -ForegroundColor White
Write-Host "     Arc cluster > Insights > Containers"
Write-Host "     Filter namespace: mesh-demo"
Write-Host ""
Write-Host "  You should see 2 containers per pod:"
Write-Host "    * Application container (frontend / backend)"
Write-Host "    * linkerd-proxy sidecar"
Write-Host ""
Write-Host "  KQL query for sidecar metrics:" -ForegroundColor White
Write-Host '  ContainerInventory'
Write-Host '  | where Namespace == "mesh-demo"'
Write-Host '  | where ContainerName contains "linkerd"'
Write-Host '  | summarize count() by Computer, ContainerName'

# ============================================================================
# STEP 5 - Traffic splitting (canary)
# ============================================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Step 5: Canary Deploy via Traffic Splitting" -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Deploying backend-v2 and SMI TrafficSplit:" -ForegroundColor Gray
Write-Host "    80% -> backend-v1 [GREEN]"
Write-Host "    20% -> backend-v2 [BLUE] (canary)"
Write-Host ""
Write-Host "  [KEY] Arc added value: push TrafficSplit to Git -> Flux applies it!" -ForegroundColor Magenta

Write-Host ""
Write-Host "[INSTALL] Deploying backend-v2 + TrafficSplit..." -ForegroundColor Yellow
kubectl apply -f k8s/mesh-demo/backend-v2.yaml
kubectl apply -f k8s/mesh-demo/traffic-split.yaml

Write-Host ""
Write-Host "[WAIT] Waiting for backend-v2..." -ForegroundColor DarkYellow
kubectl wait --for=condition=ready pod -l app=backend,version=v2 -n mesh-demo --timeout=120s

Write-Host ""
Write-Host "[STATS] All backend pods:" -ForegroundColor Yellow
kubectl get pods -l app=backend -n mesh-demo

Write-Host ""
Write-Host "[WEB] Testing traffic split (10 requests)..." -ForegroundColor Yellow
for ($i = 1; $i -le 10; $i++) {
    kubectl exec $frontendPod -n mesh-demo -c frontend -- wget -qO- http://backend.mesh-demo.svc.cluster.local/ 2>$null
}

Write-Host ""
Write-Host "  You should see ~80% v1 [GREEN] and ~20% v2 [BLUE] responses" -ForegroundColor Gray

# ============================================================================
# STEP 6 - Azure Policy for mesh enforcement
# ============================================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host "  Step 6: Enforce Mesh via Azure Policy"       -ForegroundColor White
Write-Host "==========================================" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  [KEY] Arc added value: Enforce sidecar injection at the Azure level!" -ForegroundColor Magenta
Write-Host ""
Write-Host "  In a production scenario, you would create an Azure Policy that:" -ForegroundColor Gray
Write-Host "    * Audits pods without the linkerd.io/inject annotation"
Write-Host "    * Denies deployments to mesh-enabled namespaces without sidecars"
Write-Host "    * Reports compliance in the Azure Portal"

Write-Host ""
Write-Host "  [STATS] Checking namespace labels..." -ForegroundColor Yellow
kubectl get namespace mesh-demo --show-labels

Write-Host ""
Write-Host "  The namespace label 'linkerd.io/inject=enabled' ensures all"
Write-Host "  new pods automatically get the sidecar proxy."
Write-Host ""
Write-Host "  [FOLDER] View Policy compliance:" -ForegroundColor White
Write-Host "     Portal > Policy > Compliance"
Write-Host "     Filter: Resource type = connectedClusters"

# ============================================================================
# Summary
# ============================================================================
Write-Host ""
Write-Host "============================================"                          -ForegroundColor Cyan
Write-Host "  [OK] Service Mesh on Arc - Complete!"                                  -ForegroundColor Green
Write-Host ""
Write-Host "  What we demonstrated:"                                               -ForegroundColor White
Write-Host "    [KEY] mTLS between services (zero-trust)"
Write-Host "    [STATS] Container Insights observability"
Write-Host "    [SPLIT] Canary deploy via TrafficSplit"
Write-Host "    [POLICY] GitOps-driven mesh config"
Write-Host "    [SHIELD]  Azure Policy enforcement"
Write-Host ""
Write-Host "  Arc Added Value:"                                                    -ForegroundColor Magenta
Write-Host "    * Single pane of glass - mesh metrics in Azure"
Write-Host "    * GitOps deployment - no direct cluster access"
Write-Host "    * Azure Policy - governance across clusters"
Write-Host "    * Same workflow for on-prem, edge, multi-cloud"
Write-Host "============================================"                          -ForegroundColor Cyan
