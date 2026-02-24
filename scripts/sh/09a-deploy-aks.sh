#!/bin/bash
# ============================================================================
# Script 09a - (OPTIONAL) Deploy AKS cluster for Inventory comparison
# Run from your LOCAL machine
#
# This deploys a small AKS cluster so you can demonstrate Azure Resource Graph
# queries that show Arc + AKS clusters side by side.
#
# ⚠️  EXTRA COST: ~€0.10/hour (Standard_B2s node)
#     Run cleanup when done: az group delete --name rg-arcworkshop-aks --yes
# ============================================================================
set -e

echo "============================================"
echo "  (Optional) Deploy AKS for Inventory Demo"
echo "============================================"

# --- Configuration ---
AKS_RESOURCE_GROUP="rg-arcworkshop-aks"
AKS_CLUSTER_NAME="aks-workshop-cluster"
LOCATION="${AZURE_LOCATION:-swedencentral}"

echo ""
echo "📋 Configuration:"
echo "  Resource Group: $AKS_RESOURCE_GROUP"
echo "  AKS Cluster:    $AKS_CLUSTER_NAME"
echo "  Location:       $LOCATION"
echo ""
echo "⚠️  This will incur additional Azure costs (~€0.10/hour)"
echo "  The AKS cluster uses a single Standard_B2s node"
echo ""

read -p "Continue? (y/N): " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
  echo "Cancelled."
  exit 0
fi

# --- 1. Create resource group ---
echo ""
echo "📦 Creating resource group..."
az group create --name "$AKS_RESOURCE_GROUP" --location "$LOCATION" -o none
echo "  ✅ Resource group created"

# --- 2. Deploy AKS cluster ---
echo ""
echo "🚀 Deploying AKS cluster (this takes ~5 minutes)..."
echo "  Single node, Standard_B2s (minimal cost)"

az aks create \
  --name "$AKS_CLUSTER_NAME" \
  --resource-group "$AKS_RESOURCE_GROUP" \
  --location "$LOCATION" \
  --node-count 1 \
  --node-vm-size Standard_B2s \
  --generate-ssh-keys \
  --tier free \
  -o none

echo "  ✅ AKS cluster deployed"

# --- 3. Deploy a sample workload ---
echo ""
echo "📦 Deploying sample workload to AKS..."

az aks get-credentials --name "$AKS_CLUSTER_NAME" --resource-group "$AKS_RESOURCE_GROUP" --overwrite-existing 2>/dev/null

kubectl create namespace demo --dry-run=client -o yaml | kubectl apply -f -
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-aks
  namespace: demo
  labels:
    app: hello-aks
    environment: workshop
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-aks
  template:
    metadata:
      labels:
        app: hello-aks
        environment: workshop
    spec:
      containers:
        - name: hello-aks
          image: mcr.microsoft.com/azuredocs/aks-helloworld:v1
          ports:
            - containerPort: 80
          env:
            - name: TITLE
              value: "Hello from AKS! ☁️"
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
EOF

echo "  ✅ Sample workload deployed"

# --- 4. Show comparison ---
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔍 Arc + AKS side by side:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

az graph query -q "
  resources
  | where type in (
      'microsoft.kubernetes/connectedclusters',
      'microsoft.containerservice/managedclusters')
  | extend clusterType = iff(type contains 'connected', 'Arc', 'AKS')
  | project name, clusterType, resourceGroup, location,
            k8sVersion=properties.kubernetesVersion
  | order by clusterType, name
" -o table

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Now run script 09 again to see both clusters"
echo "  in the Resource Graph queries!"
echo ""
echo "  ⚠️  Cleanup when done:"
echo "  az group delete --name $AKS_RESOURCE_GROUP --yes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "============================================"
echo "  ✅ AKS cluster ready for inventory demo!"
echo "============================================"
