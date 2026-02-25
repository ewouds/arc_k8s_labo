# ============================================================================
# Script 05a - Toggle Governance Policies (Disable / Enable)
# Run from your LOCAL machine (PowerShell)
#
# Usage:
#   .\scripts\ps1\05a-toggle-policies.ps1 disable   # Set policies to audit-only
#   .\scripts\ps1\05a-toggle-policies.ps1 enable     # Re-enable enforcement
# ============================================================================
$ErrorActionPreference = "Stop"

$action = if ($args[0]) { $args[0].ToLower() } else { $null }

if ($action -notin @("disable", "enable")) {
    Write-Host ""
    Write-Host "Usage: .\05a-toggle-policies.ps1 <disable|enable>" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  disable  - Set policies to DoNotEnforce (audit-only)" -ForegroundColor DarkGray
    Write-Host "  enable   - Set policies back to Default (enforce)" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Example: .\05a-toggle-policies.ps1 disable" -ForegroundColor DarkGray
    exit 1
}

# --- Configuration ---
$resourceGroup = if ($env:RESOURCE_GROUP) { $env:RESOURCE_GROUP } else { "rg-arcworkshop" }
$clusterName = if ($env:CLUSTER_NAME) { $env:CLUSTER_NAME }   else { "arc-k3s-cluster" }

$clusterId = az connectedk8s show -n $clusterName -g $resourceGroup --query id -o tsv 2>$null
if (-not $clusterId) {
    Write-Host "  [ERROR] Could not find Arc cluster '$clusterName' in '$resourceGroup'" -ForegroundColor Red
    exit 1
}

# Policy assignment names (from 05-governance.ps1)
$policyNames = @(
    "no-privileged-containers"
    "require-env-label"
    "allowed-registries"
)

if ($action -eq "disable") {
    $mode = "DoNotEnforce"
    $label = "DISABLED (audit-only)"
    $color = "DarkYellow"
    $icon = "[PAUSE]"
}
else {
    $mode = "Default"
    $label = "ENABLED (enforcing)"
    $color = "Green"
    $icon = "[PLAY]"
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  $icon  Policies -> $label"                   -ForegroundColor $color
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

foreach ($pol in $policyNames) {
    $exists = az policy assignment show --name $pol --scope $clusterId 2>$null
    if ($exists) {
        az policy assignment update --name $pol --scope $clusterId --enforcement-mode $mode 2>$null | Out-Null
        Write-Host "  [OK] $pol -> $mode" -ForegroundColor $color
    }
    else {
        Write-Host "  [SKIP]  $pol (not found, skipping)" -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "  Done. Policies are now $label." -ForegroundColor $color
Write-Host ""
