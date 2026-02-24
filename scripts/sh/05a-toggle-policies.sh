#!/bin/bash
# ============================================================================
# Script 05a - Toggle Governance Policies (Disable / Enable)
# Run from your LOCAL machine
#
# Usage:
#   ./scripts/sh/05a-toggle-policies.sh disable   # Set policies to audit-only
#   ./scripts/sh/05a-toggle-policies.sh enable     # Re-enable enforcement
# ============================================================================
set -e

ACTION="${1,,}"  # lowercase

if [[ "$ACTION" != "disable" && "$ACTION" != "enable" ]]; then
    echo ""
    echo "Usage: ./05a-toggle-policies.sh <disable|enable>"
    echo ""
    echo "  disable  — Set policies to DoNotEnforce (audit-only)"
    echo "  enable   — Set policies back to Default (enforce)"
    echo ""
    echo "Example: ./05a-toggle-policies.sh disable"
    exit 1
fi

# --- Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arcworkshop}"
CLUSTER_NAME="${CLUSTER_NAME:-arc-k3s-cluster}"

CLUSTER_ID=$(az connectedk8s show -n "$CLUSTER_NAME" -g "$RESOURCE_GROUP" --query id -o tsv 2>/dev/null)
if [ -z "$CLUSTER_ID" ]; then
    echo "  ❌ Could not find Arc cluster '$CLUSTER_NAME' in '$RESOURCE_GROUP'"
    exit 1
fi

# Policy assignment names (from 05-governance.sh)
POLICY_NAMES=(
    "no-privileged-containers"
    "require-env-label"
    "allowed-registries"
)

if [ "$ACTION" = "disable" ]; then
    MODE="DoNotEnforce"
    LABEL="DISABLED (audit-only)"
    ICON="⏸️"
else
    MODE="Default"
    LABEL="ENABLED (enforcing)"
    ICON="▶️"
fi

echo ""
echo "============================================"
echo "  $ICON  Policies → $LABEL"
echo "============================================"
echo ""

for POL in "${POLICY_NAMES[@]}"; do
    if az policy assignment show --name "$POL" --scope "$CLUSTER_ID" &>/dev/null; then
        az policy assignment update --name "$POL" --scope "$CLUSTER_ID" --enforcement-mode "$MODE" &>/dev/null
        echo "  ✅ $POL → $MODE"
    else
        echo "  ⏭️  $POL (not found, skipping)"
    fi
done

echo ""
echo "  Done. Policies are now $LABEL."
echo ""
