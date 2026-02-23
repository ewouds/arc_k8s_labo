#!/bin/bash
# ============================================================================
# Script 00 - Prerequisites Check & Azure Provider Registration
# Run BEFORE `azd provision` (also used as AZD preprovision hook)
# ============================================================================
set -e

echo "============================================"
echo "  Arc-enabled K8s Workshop - Prerequisites"
echo "============================================"

# --- 1. Check required CLI tools ---
echo ""
echo "🔍 Checking required tools..."

command -v az >/dev/null 2>&1 || { echo "❌ Azure CLI (az) not found. Install: https://aka.ms/InstallAzureCLI"; exit 1; }
echo "  ✅ Azure CLI $(az version --query '\"azure-cli\"' -o tsv)"

command -v azd >/dev/null 2>&1 || { echo "❌ Azure Developer CLI (azd) not found. Install: https://aka.ms/azd-install"; exit 1; }
echo "  ✅ Azure Developer CLI $(azd version)"

command -v kubectl >/dev/null 2>&1 || echo "  ⚠️  kubectl not found (optional, install: https://kubernetes.io/docs/tasks/tools/)"
command -v ssh >/dev/null 2>&1 || echo "  ⚠️  SSH client not found"

# --- 2. Verify Azure login ---
echo ""
echo "🔍 Checking Azure login..."
ACCOUNT=$(az account show --query '{name:name, id:id, tenantId:tenantId}' -o table 2>/dev/null) || {
  echo "❌ Not logged in. Run: az login"
  exit 1
}
echo "$ACCOUNT"

# --- 3. Register required Azure Resource Providers ---
echo ""
echo "📋 Registering required Azure resource providers..."

PROVIDERS=(
  "Microsoft.Kubernetes"              # Arc-enabled K8s
  "Microsoft.KubernetesConfiguration" # GitOps / Flux
  "Microsoft.ExtendedLocation"        # Custom Locations
  "Microsoft.PolicyInsights"          # Azure Policy
  "Microsoft.Security"                # Microsoft Defender
  "Microsoft.Monitor"                 # Azure Monitor
  "Microsoft.OperationalInsights"     # Log Analytics
  "Microsoft.Insights"                # Application Insights
)

for PROVIDER in "${PROVIDERS[@]}"; do
  STATE=$(az provider show --namespace "$PROVIDER" --query "registrationState" -o tsv 2>/dev/null || echo "NotRegistered")
  if [ "$STATE" == "Registered" ]; then
    echo "  ✅ $PROVIDER (already registered)"
  else
    echo "  ⏳ Registering $PROVIDER..."
    az provider register --namespace "$PROVIDER" --wait
    echo "  ✅ $PROVIDER (registered)"
  fi
done

# --- 4. Install/update required Azure CLI extensions ---
echo ""
echo "📦 Installing/updating Azure CLI extensions..."

EXTENSIONS=(
  "connectedk8s"          # Arc-enabled Kubernetes
  "k8s-configuration"     # GitOps / Flux configuration
  "k8s-extension"         # K8s extensions (monitoring, defender, etc.)
  "customlocation"        # Custom Locations
  "resource-graph"        # Azure Resource Graph queries
)

for EXT in "${EXTENSIONS[@]}"; do
  if az extension show --name "$EXT" &>/dev/null; then
    echo "  ✅ $EXT (installed, upgrading...)"
    az extension update --name "$EXT" 2>/dev/null || true
  else
    echo "  ⏳ Installing $EXT..."
    az extension add --name "$EXT" --yes
    echo "  ✅ $EXT (installed)"
  fi
done

echo ""
echo "============================================"
echo "  ✅ All prerequisites satisfied!"
echo "  Next: run 'azd provision' or 'azd up'"
echo "============================================"
