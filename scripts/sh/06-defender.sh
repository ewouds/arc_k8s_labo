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

# --- 3. Verify Defender pods on the cluster ---
echo ""
echo "🔍 Verifying Defender pods on the cluster..."

VM_IP="${VM_IP:-20.240.42.92}"
VM_USER="${VM_USER:-azureuser}"

if ssh "${VM_USER}@${VM_IP}" "KUBECONFIG=~/.kube/config kubectl get pods -n mdc --no-headers 2>/dev/null" 2>/dev/null; then
  echo "  ✅ Defender sensor pods are running"
else
  echo "  ⚠️  No Defender pods found yet (namespace 'mdc' may take a few minutes)"
fi

# --- 4. Trigger a test security alert ---
echo ""
echo "🧪 Triggering a test security alert..."
echo "  Running the official Microsoft Defender test alert container"
echo ""
echo "  ⚠️  If governance policies (Section 5) are active, disable them first:"
echo "     bash scripts/sh/05a-toggle-policies.sh disable"
echo "     (Re-enable after the test with: bash scripts/sh/05a-toggle-policies.sh enable)"
echo ""

ssh "${VM_USER}@${VM_IP}" "KUBECONFIG=~/.kube/config kubectl delete pod defender-test --ignore-not-found 2>/dev/null; KUBECONFIG=~/.kube/config kubectl run defender-test --image=mcr.microsoft.com/aks/security/test-alert --restart=Never --labels=environment=workshop 2>/dev/null"
if [ $? -eq 0 ]; then
  echo "  ✅ Test alert triggered — will appear in Defender for Cloud within ~30 min"
else
  echo "  ⚠️  Could not trigger test alert (check SSH connectivity)"
fi

# --- 5. Portal walkthrough ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 Portal Demo Walkthrough:"
echo ""
echo "  1. Defender for Cloud > Workload protections > Containers"
echo "     → Your Arc cluster is listed with Defender coverage"
echo ""
echo "  2. Defender for Cloud > Security alerts"
echo "     → Test alert appears here (~30 min delay)"
echo ""
echo "  3. Defender for Cloud > Recommendations"
echo "     → Filter by connectedClusters for hardening tips"
echo ""
echo "  4. Arc cluster > Security (blade)"
echo "     → Defender status directly on the Arc resource"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# --- 6. Cleanup & re-enable policies ---
echo ""
echo "🧹 Cleanup (run after demo):"
echo "  ssh ${VM_USER}@${VM_IP} \"kubectl delete pod defender-test --ignore-not-found\""
echo "  bash scripts/sh/05a-toggle-policies.sh enable"

echo ""
echo "============================================"
echo "  ✅ Microsoft Defender configured!"
echo "============================================"
