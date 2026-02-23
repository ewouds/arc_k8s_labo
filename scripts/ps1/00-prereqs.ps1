# ============================================================================
# Script 00 - Prerequisites Check & Azure Provider Registration
# Run BEFORE `azd provision` (also used as AZD preprovision hook)
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Arc-enabled K8s Workshop - Prerequisites"  -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- 1. Check required CLI tools ---
Write-Host ""
Write-Host "🔍 Checking required tools..." -ForegroundColor Yellow

try { $azVer = (az version | ConvertFrom-Json).'azure-cli'; Write-Host "  ✅ Azure CLI $azVer" -ForegroundColor Green }
catch { Write-Host "  ❌ Azure CLI (az) not found. Install: https://aka.ms/InstallAzureCLI" -ForegroundColor Red; exit 1 }

try { $azdVer = azd version; Write-Host "  ✅ Azure Developer CLI $azdVer" -ForegroundColor Green }
catch { Write-Host "  ❌ Azure Developer CLI (azd) not found. Install: https://aka.ms/azd-install" -ForegroundColor Red; exit 1 }

if (Get-Command kubectl -ErrorAction SilentlyContinue) { Write-Host "  ✅ kubectl found" -ForegroundColor Green }
else { Write-Host "  ⚠️  kubectl not found (optional)" -ForegroundColor DarkYellow }

if (Get-Command ssh -ErrorAction SilentlyContinue) { Write-Host "  ✅ SSH client found" -ForegroundColor Green }
else { Write-Host "  ⚠️  SSH client not found" -ForegroundColor DarkYellow }

# --- 2. Verify Azure login ---
Write-Host ""
Write-Host "🔍 Checking Azure login..." -ForegroundColor Yellow
try {
    $account = az account show | ConvertFrom-Json
    Write-Host "  ✅ Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "  Subscription:    $($account.name) ($($account.id))" 
}
catch {
    Write-Host "  ❌ Not logged in. Run: az login" -ForegroundColor Red
    exit 1
}

# --- 3. Register required Azure Resource Providers ---
Write-Host ""
Write-Host "📋 Registering required Azure resource providers..." -ForegroundColor Yellow

$providers = @(
    "Microsoft.Kubernetes"              # Arc-enabled K8s
    "Microsoft.KubernetesConfiguration" # GitOps / Flux
    "Microsoft.ExtendedLocation"        # Custom Locations
    "Microsoft.PolicyInsights"          # Azure Policy
    "Microsoft.Security"                # Microsoft Defender
    "Microsoft.Monitor"                 # Azure Monitor
    "Microsoft.OperationalInsights"     # Log Analytics
    "Microsoft.Insights"                # Application Insights
)

foreach ($provider in $providers) {
    $state = (az provider show --namespace $provider --query "registrationState" -o tsv 2>$null)
    if ($state -eq "Registered") {
        Write-Host "  ✅ $provider (already registered)" -ForegroundColor Green
    }
    else {
        Write-Host "  ⏳ Registering $provider..." -ForegroundColor DarkYellow
        az provider register --namespace $provider --wait | Out-Null
        Write-Host "  ✅ $provider (registered)" -ForegroundColor Green
    }
}

# --- 4. Install/update required Azure CLI extensions ---
Write-Host ""
Write-Host "📦 Installing/updating Azure CLI extensions..." -ForegroundColor Yellow

$extensions = @(
    "connectedk8s"      # Arc-enabled Kubernetes
    "k8s-configuration" # GitOps / Flux configuration
    "k8s-extension"     # K8s extensions (monitoring, defender, etc.)
    "customlocation"    # Custom Locations
    "resource-graph"    # Azure Resource Graph queries
)

foreach ($ext in $extensions) {
    $installed = az extension show --name $ext 2>$null
    if ($installed) {
        Write-Host "  ✅ $ext (installed, upgrading...)" -ForegroundColor Green
        az extension update --name $ext 2>$null
    }
    else {
        Write-Host "  ⏳ Installing $ext..." -ForegroundColor DarkYellow
        az extension add --name $ext --yes | Out-Null
        Write-Host "  ✅ $ext (installed)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  ✅ All prerequisites satisfied!"          -ForegroundColor Green
Write-Host "  Next: run 'azd provision' or 'azd up'"    -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
