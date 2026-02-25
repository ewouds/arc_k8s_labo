#!/bin/bash
# ============================================================================
# Script 00 - Prerequisites Check & Azure Provider Registration
# Run BEFORE `azd provision` or `az deployment sub create`
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

command -v azd >/dev/null 2>&1 && echo "  ✅ Azure Developer CLI $(azd version)" || {
  echo "  ⚠️  Azure Developer CLI (azd) not found (recommended). Install: https://aka.ms/azd-install"
  echo "          You can still deploy with: az deployment sub create (see workshop for details)"
}

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

# --- 5. Check VM SKU capacity in selected region ---
echo ""
echo "🔍 Checking VM SKU availability..."

VM_SIZE="${VM_SIZE:-Standard_D4s_v3}"
LOCATION="${AZURE_LOCATION:-}"

if [ -n "$LOCATION" ]; then
  SKU_JSON=$(az vm list-skus --location "$LOCATION" --size "$VM_SIZE" --resource-type virtualMachines -o json 2>/dev/null)
  SKU_COUNT=$(echo "$SKU_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

  if [ "$SKU_COUNT" -eq 0 ]; then
    echo "  ❌ VM size '$VM_SIZE' is not available in region '$LOCATION'."
    echo "     Choose a different region or set VM_SIZE to an available SKU."
    echo "     Check available sizes: az vm list-skus --location $LOCATION --resource-type virtualMachines --query \"[?name=='$VM_SIZE']\" -o table"
    exit 1
  fi

  LOC_RESTRICTED=$(echo "$SKU_JSON" | python3 -c "
import sys, json
skus = json.load(sys.stdin)
for s in skus:
    for r in s.get('restrictions', []):
        if r.get('type') == 'Location':
            print(r.get('reasonCode', 'Unknown'))
            sys.exit(0)
" 2>/dev/null || echo "")

  if [ -n "$LOC_RESTRICTED" ]; then
    echo "  ❌ VM size '$VM_SIZE' is restricted in region '$LOCATION'."
    echo "     Reason: $LOC_RESTRICTED"
    echo "     Choose a different region or set VM_SIZE to an available SKU."
    exit 1
  fi

  # Check for zone restrictions (warning only)
  ZONE_RESTRICTED=$(echo "$SKU_JSON" | python3 -c "
import sys, json
skus = json.load(sys.stdin)
for s in skus:
    for r in s.get('restrictions', []):
        if r.get('type') == 'Zone':
            print('yes')
            sys.exit(0)
" 2>/dev/null || echo "")

  if [ -n "$ZONE_RESTRICTED" ]; then
    echo "  ⚠️  VM size '$VM_SIZE' has zone restrictions in '$LOCATION' (some AZs unavailable)"
  fi

  echo "  ✅ VM size '$VM_SIZE' is available in '$LOCATION'"
else
  echo "  ⏭️  Skipping (AZURE_LOCATION not set yet — azd will prompt)"
fi

echo ""
echo "============================================"
echo "  ✅ All prerequisites satisfied!"
echo "  Next: run 'azd provision' or 'azd up' (or 'az deployment sub create')"
echo "============================================"
