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
Write-Host "[CHECK] Checking required tools..." -ForegroundColor Yellow

try { $azVer = (az version | ConvertFrom-Json).'azure-cli'; Write-Host "  [OK] Azure CLI $azVer" -ForegroundColor Green }
catch { Write-Host "  [ERROR] Azure CLI (az) not found. Install: https://aka.ms/InstallAzureCLI" -ForegroundColor Red; exit 1 }

try { $azdVer = azd version; Write-Host "  [OK] Azure Developer CLI $azdVer" -ForegroundColor Green }
catch { Write-Host "  [ERROR] Azure Developer CLI (azd) not found. Install: https://aka.ms/azd-install" -ForegroundColor Red; exit 1 }

if (Get-Command kubectl -ErrorAction SilentlyContinue) { Write-Host "  [OK] kubectl found" -ForegroundColor Green }
else { Write-Host "  [WARN]  kubectl not found (optional)" -ForegroundColor DarkYellow }

if (Get-Command ssh -ErrorAction SilentlyContinue) { Write-Host "  [OK] SSH client found" -ForegroundColor Green }
else { Write-Host "  [WARN]  SSH client not found" -ForegroundColor DarkYellow }

# --- 2. Verify Azure login ---
Write-Host ""
Write-Host "[CHECK] Checking Azure login..." -ForegroundColor Yellow
try {
    $account = az account show | ConvertFrom-Json
    Write-Host "  [OK] Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "  Subscription:    $($account.name) ($($account.id))" 
}
catch {
    Write-Host "  [ERROR] Not logged in. Run: az login" -ForegroundColor Red
    exit 1
}

# --- 3. Register required Azure Resource Providers ---
Write-Host ""
Write-Host "[INFO] Registering required Azure resource providers..." -ForegroundColor Yellow

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
        Write-Host "  [OK] $provider (already registered)" -ForegroundColor Green
    }
    else {
        Write-Host "  [WAIT] Registering $provider..." -ForegroundColor DarkYellow
        az provider register --namespace $provider --wait | Out-Null
        Write-Host "  [OK] $provider (registered)" -ForegroundColor Green
    }
}

# --- 4. Install/update required Azure CLI extensions ---
Write-Host ""
Write-Host "[INSTALL] Installing/updating Azure CLI extensions..." -ForegroundColor Yellow

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
        Write-Host "  [OK] $ext (installed, upgrading...)" -ForegroundColor Green
        az extension update --name $ext 2>$null
    }
    else {
        Write-Host "  [WAIT] Installing $ext..." -ForegroundColor DarkYellow
        az extension add --name $ext --yes | Out-Null
        Write-Host "  [OK] $ext (installed)" -ForegroundColor Green
    }
}

# --- 5. Check VM SKU capacity in selected region ---
Write-Host ""
Write-Host "[CHECK] Checking VM SKU availability..." -ForegroundColor Yellow

$vmSize = if ($env:VM_SIZE) { $env:VM_SIZE } else { "Standard_D4s_v3" }
$location = if ($env:AZURE_LOCATION) { $env:AZURE_LOCATION } else { $null }

if ($location) {
    $skuJson = az vm list-skus --location $location --size $vmSize --resource-type virtualMachines -o json 2>$null
    $skuInfo = $skuJson | ConvertFrom-Json

    if (-not $skuInfo -or $skuInfo.Count -eq 0) {
        Write-Host "  [ERROR] VM size '$vmSize' is not available in region '$location'." -ForegroundColor Red
        Write-Host "     Choose a different region or set VM_SIZE to an available SKU." -ForegroundColor Red
        Write-Host "     Check available sizes: az vm list-skus --location $location --resource-type virtualMachines --query `"[?name=='$vmSize']`" -o table" -ForegroundColor DarkYellow
        exit 1
    }

    $restricted = $skuInfo | Where-Object {
        $_.restrictions | Where-Object { $_.type -eq 'Location' }
    }
    if ($restricted) {
        Write-Host "  [ERROR] VM size '$vmSize' is restricted in region '$location'." -ForegroundColor Red
        Write-Host "     Reason: $($restricted[0].restrictions[0].reasonCode)" -ForegroundColor Red
        Write-Host "     Choose a different region or set VM_SIZE to an available SKU." -ForegroundColor Red
        exit 1
    }

    # Check for zone restrictions (warning only)
    $zoneRestricted = $skuInfo | Where-Object {
        $_.restrictions | Where-Object { $_.type -eq 'Zone' }
    }
    if ($zoneRestricted) {
        Write-Host "  [WARN]  VM size '$vmSize' has zone restrictions in '$location' (some AZs unavailable)" -ForegroundColor DarkYellow
    }

    Write-Host "  [OK] VM size '$vmSize' is available in '$location'" -ForegroundColor Green
}
else {
    Write-Host "hey" -ForegroundColor DarkYellow
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  [OK] All prerequisites satisfied!"          -ForegroundColor Green
Write-Host "  Next: run 'azd provision' or 'azd up'"    -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
