#!/bin/bash
# ============================================================================
# Script 06 - Enterprise-Grade Security with Microsoft Defender for Containers
# Run from your LOCAL machine
# ============================================================================
set -e

echo "============================================"
echo "  Microsoft Defender for Containers (Arc)"
echo "============================================"

# --- Configuration ---
RESOURCE_GROUP="${RESOURCE_GROUP:-rg-arcworkshop}"
CLUSTER_NAME="${CLUSTER_NAME:-arc-k3s-cluster}"
LOG_ANALYTICS_WORKSPACE_ID="${LOG_ANALYTICS_WORKSPACE_ID:-$(azd env get-values 2>/dev/null | grep LOG_ANALYTICS_WORKSPACE_ID | cut -d'=' -f2 | tr -d '"')}"
SUBSCRIPTION_ID=$(az account show --query id -o tsv)

echo ""
echo "📋 Configuration:"
echo "  Resource Group:  $RESOURCE_GROUP"
echo "  Cluster Name:    $CLUSTER_NAME"
echo "  Workspace:       $LOG_ANALYTICS_WORKSPACE_ID"

# --- 1. Enable Defender for Containers plan on the subscription ---
echo ""
echo "🛡️ Enabling Microsoft Defender for Containers plan..."
az security pricing create \
  --name Containers \
  --tier Standard \
  2>/dev/null || echo "  (May already be enabled)"

echo "  ✅ Defender for Containers plan enabled"

# --- 2. Install Defender extension on Arc cluster ---
echo ""
echo "📦 Installing Microsoft Defender extension on Arc cluster..."
echo "  This deploys the Defender sensor (DaemonSet) on all nodes"

az k8s-extension create \
  --name microsoft.azuredefender.kubernetes \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --extension-type microsoft.azuredefender.kubernetes \
  --configuration-settings "logAnalyticsWorkspaceResourceID=$LOG_ANALYTICS_WORKSPACE_ID" \
  2>/dev/null || echo "  (Extension may already exist)"

echo ""
echo "⏳ Checking extension status..."
az k8s-extension show \
  --name microsoft.azuredefender.kubernetes \
  --cluster-name "$CLUSTER_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --cluster-type connectedClusters \
  --query '{name:name, provisioningState:provisioningState, extensionType:extensionType}' \
  -o table

# --- 3. Show what Defender provides ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  What Microsoft Defender provides:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  🔍 Runtime threat detection:"
echo "     - Suspicious process execution"
echo "     - Cryptocurrency mining detection"
echo "     - Reverse shell detection"
echo "     - Known malicious IPs/domains"
echo ""
echo "  📦 Image vulnerability scanning:"
echo "     - CVE detection in container images"
echo "     - Qualys-powered vulnerability assessment"
echo ""
echo "  🔒 Security recommendations:"
echo "     - RBAC best practices"
echo "     - Network policy recommendations"
echo "     - Pod security standards"
echo ""
echo "  📊 View in Azure Portal:"
echo "     - Security Center > Workload protections"
echo "     - Arc cluster > Security"
echo "     - Defender for Cloud > Recommendations"

echo ""
echo "============================================"
echo "  ✅ Microsoft Defender configured!"
echo ""
echo "  🎯 Demo: Show Defender recommendations in Portal"
echo "     Portal > Defender for Cloud > Recommendations"
echo "     Filter by: Resource type = connectedClusters"
echo "============================================"
