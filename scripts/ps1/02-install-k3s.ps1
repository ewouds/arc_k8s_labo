# ============================================================================
# Script 02 - Install K3s (Lightweight Kubernetes by Rancher)
# Run this ON THE VM via SSH (copy-paste commands)
# ============================================================================
# Usage:
#   1. SSH into the VM:  ssh azureuser@<VM_PUBLIC_IP>
#   2. Run these commands on the VM (bash)
#
# NOTE: K3s runs on Linux. This script SSHs into the VM and runs the install.
# ============================================================================
$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Install K3s on the VM via SSH"            -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan

# --- Get VM IP from AZD ---
$vmIp = (azd env get-value VM_PUBLIC_IP 2>$null)
if (-not $vmIp) {
    $vmIp = Read-Host "Enter VM Public IP"
}
$vmUser = "azureuser"

Write-Host ""
Write-Host "[INFO] Target: $vmUser@$vmIp" -ForegroundColor Yellow

Write-Host ""
Write-Host "[RUN] Installing K3s via SSH..." -ForegroundColor Yellow
Write-Host "  This will:"
Write-Host "    1. Update system packages"
Write-Host "    2. Install K3s (single-node cluster)"
Write-Host "    3. Configure kubectl"
Write-Host ""

# SSH into VM and run install
$sshTarget = "${vmUser}@${vmIp}"
$sshCommand = @'
set -e
echo '[INSTALL] Updating system packages...'
sudo apt-get update -y && sudo apt-get upgrade -y

echo '[RUN] Installing K3s...'
curl -sfL https://get.k3s.io | sh -

echo '[WAIT] Waiting for K3s...'
sleep 10

echo '[CONFIG] Configuring kubectl...'
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
# Also set in /etc/environment so non-interactive SSH sessions pick it up
echo 'KUBECONFIG=/home/azureuser/.kube/config' | sudo tee -a /etc/environment > /dev/null
# Make k3s.yaml readable as fallback
sudo chmod 644 /etc/rancher/k3s/k3s.yaml

echo ''
echo '--- Node Status ---'
kubectl get nodes -o wide
echo ''
echo '--- System Pods ---'
kubectl get pods -A
echo ''
echo '--- K3s Version ---'
k3s --version

echo ''
echo '[OK] K3s installed and running!'
'@

# Strip Windows carriage returns to avoid \r errors on Linux
$sshCommand = $sshCommand -replace "`r", ""

ssh -o StrictHostKeyChecking=no $sshTarget $sshCommand

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  [OK] K3s installation complete!"            -ForegroundColor Green
Write-Host "  Next: Run 03-arc-onboard.ps1"             -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
