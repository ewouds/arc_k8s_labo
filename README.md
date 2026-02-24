# Azure Arc-enabled Kubernetes Workshop

A complete, reproducible workshop for demonstrating Azure Arc-enabled Kubernetes capabilities. Uses **Azure Developer CLI (AZD)** and **Bicep** for infrastructure deployment.

## Quick Start

```bash
# 1. Prerequisites (bash)
bash scripts/sh/00-prereqs.sh

# Or PowerShell:
# .\scripts\ps1\00-prereqs.ps1

# 2. Initialize AZD
azd init

# 3. Deploy everything
azd up
# → Environment: arcworkshop
# → Location: westeurope
# → VM Password: <strong password, min 12 chars>

# 4. Get connection details
azd env get-values
```

## Project Structure

```
arc_k8s/
├── azure.yaml                    # AZD project configuration
├── WORKSHOP-EN.md                # 📋 Workshop guide (English)
├── README.md                     # This file
│
├── infra/                        # Bicep infrastructure-as-code
│   ├── main.bicep                # Main orchestrator (subscription scope)
│   ├── main.parameters.json      # AZD parameter mapping
│   └── modules/
│       ├── network.bicep         # VNet, Subnet, NSG, Public IP
│       ├── vm.bicep              # Ubuntu 22.04 VM (K3s host)
│       ├── loganalytics.bicep    # Log Analytics Workspace
│       └── aks.bicep             # (Optional) AKS cluster for inventory comparison
│
├── scripts/                      # Demo scripts (numbered by workshop step)
│   ├── sh/                       # Bash/Shell scripts (Linux / WSL / Git Bash)
│   │   ├── 00-prereqs.sh
│   │   ├── 02-install-k3s.sh
│   │   ├── 03-arc-onboard.sh
│   │   ├── 04-deploy-container.sh
│   │   ├── 05-governance.sh
│   │   ├── 05a-toggle-policies.sh   # Toggle policies on/off
│   │   ├── 06-defender.sh
│   │   ├── 07-monitoring.sh
│   │   ├── 08-gitops.sh
│   │   ├── 09-inventory.sh
│   │   ├── postprovision.sh          # Post-provision hook (AKS workload)
│   │   └── 99-cleanup.sh
│   └── ps1/                      # PowerShell scripts (Windows native)
│       ├── 00-prereqs.ps1
│       ├── 02-install-k3s.ps1
│       ├── 03-arc-onboard.ps1
│       ├── 04-deploy-container.ps1
│       ├── 05-governance.ps1
│       ├── 05a-toggle-policies.ps1 # Toggle policies on/off
│       ├── 06-defender.ps1
│       ├── 07-monitoring.ps1
│       ├── 08-gitops.ps1
│       ├── 09-inventory.ps1
│       ├── postprovision.ps1      # Post-provision hook (AKS workload)
│       └── 99-cleanup.ps1
│
├── k8s/                          # Kubernetes manifests for demos
│   ├── demo-app.yaml             # Nginx demo deployment (step 4)
│   └── privileged-pod.yaml       # Privileged pod (blocked by policy, step 5)
│
└── gitops/                       # GitOps source manifests (step 8)
    ├── kustomization.yaml
    ├── namespaces/
    │   └── demo-ns.yaml
    └── apps/
        └── hello-arc.yaml
```

## Prerequisites

| Tool                      | Install                                 |
| ------------------------- | --------------------------------------- |
| Azure CLI                 | https://aka.ms/InstallAzureCLI          |
| Azure Developer CLI (azd) | https://aka.ms/azd-install              |
| kubectl                   | https://kubernetes.io/docs/tasks/tools/ |
| SSH client                | Built-in on Windows 10+                 |

**Azure subscription** with Owner or Contributor + User Access Administrator roles.

## Workshop Flow

See the workshop guide in your preferred language:

- **English:** [WORKSHOP-EN.md](WORKSHOP-EN.md)

| Step | Duration | What                            |
| ---- | -------- | ------------------------------- |
| 0    | 5 min    | Introduction & Architecture     |
| 1    | 10 min   | Deploy infra with AZD + Bicep   |
| 2    | 10 min   | SSH + Install K3s               |
| 3    | 10 min   | Arc onboarding                  |
| 4    | 10 min   | Deploy container from Azure     |
| 5    | 10 min   | Azure Policy governance         |
| 6    | 5 min    | Microsoft Defender              |
| 7    | 10 min   | Monitoring & Container Insights |
| 8    | 10 min   | GitOps with Flux                |
| 9    | 5 min    | Inventory management            |
| 10   | 5 min    | Copilot for Azure               |
| —    | 5 min    | Q&A + Cleanup                   |

## Cleanup

```bash
# Recommended: removes everything
azd down --purge --force

# Alternative: delete resource group
az group delete --name rg-arcworkshop --yes
```

## Cost Estimate

| Resource      | SKU             | ~Cost/hour        |
| ------------- | --------------- | ----------------- |
| VM            | Standard_D4s_v3 | €0.19             |
| Public IP     | Standard Static | €0.004            |
| Log Analytics | PerGB2018       | Pay per ingestion |
| **Total**     |                 | **~€0.20/hour**   |

> **Optional:** Set `deployAks=true` during `azd up` to include a small AKS cluster (Standard_B2s, ~€0.10/hour extra) for the inventory comparison demo in Exercise 9.

> **Tip:** Run `azd down` immediately after the workshop to stop costs.
