#!/bin/bash
# ============================================================================
# Script 02 - Install K3s (Lightweight Kubernetes by Rancher)
# Run this ON THE VM via SSH
# ============================================================================
# Usage:
#   1. SSH into the VM:  ssh azureuser@<VM_PUBLIC_IP>
#   2. Run this script:  bash 02-install-k3s.sh
# ============================================================================
set -e

echo "============================================"
echo "  Installing K3s (Rancher Lightweight K8s)"
echo "============================================"

# --- 1. Update system packages ---
echo ""
echo "📦 Updating system packages..."
sudo apt-get update -y && sudo apt-get upgrade -y

# --- 2. Install K3s ---
echo ""
echo "🚀 Installing K3s..."
# K3s installs as a single binary with everything included:
#   - containerd (container runtime)
#   - Flannel (CNI networking)
#   - CoreDNS
#   - Traefik (ingress controller)
#   - Local-path storage provisioner
#   - Embedded etcd (or SQLite for single node)
curl -sfL https://get.k3s.io | sh -

# --- 3. Wait for K3s to be ready ---
echo ""
echo "⏳ Waiting for K3s to be ready..."
sleep 10

# --- 4. Configure kubectl for the current user ---
echo ""
echo "🔧 Configuring kubectl access for user $(whoami)..."
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc

# --- 5. Verify K3s installation ---
echo ""
echo "🔍 Verifying K3s installation..."
echo ""
echo "--- Node Status ---"
kubectl get nodes -o wide
echo ""
echo "--- System Pods ---"
kubectl get pods -A
echo ""
echo "--- K3s Version ---"
k3s --version
echo ""
echo "--- Cluster Info ---"
kubectl cluster-info

echo ""
echo "============================================"
echo "  ✅ K3s installed and running!"
echo ""
echo "  Node: $(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')"
echo "  K8s:  $(kubectl version --short 2>/dev/null | head -1)"
echo ""
echo "  Next: Run script 03-arc-onboard.sh"
echo "============================================"
