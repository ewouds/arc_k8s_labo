# Azure Arc-enabled Kubernetes — Hands-On Lab

> **Audience:** Cloud Engineers / DevOps  
> **Level:** Intermediate – Advanced  
> **Duration:** 1–1.5 hours (self-paced)  
> **Prerequisites:** Azure subscription (Owner/Contributor), Azure CLI + AZD CLI installed  
> **Repository:** This folder is a fully self-contained AZD project

> [!WARNING] **Security Disclaimer — Lab Use Only**  
> This lab is designed for **learning and demonstration purposes**. Several practices used here do **not** follow security best practices for production environments. Examples include:
>
> - Direct SSH access with password authentication (use SSH keys, Azure Bastion, or Just-in-Time VM access instead)
> - Opening ports (22, 443, 6443) directly on the public internet via NSG rules
> - Using `--use-device-code` login on a remote VM
> - Password-based VM authentication instead of Managed Identity / SSH keys
> - Broad Contributor/Owner role assignments
>
> **In production, always apply the principle of least privilege, use private endpoints, enable network segmentation, and follow the Azure security baseline.**
>
> Recommended reading:
>
> - [Azure Security Best Practices](https://learn.microsoft.com/azure/security/fundamentals/best-practices-and-patterns)
> - [Azure Arc-enabled Kubernetes Security](https://learn.microsoft.com/azure/azure-arc/kubernetes/security-overview)
> - [AKS/K8s Security Baseline](https://learn.microsoft.com/security/benchmark/azure/baselines/azure-kubernetes-service-aks-security-baseline)
> - [Azure Bastion (secure VM access)](https://learn.microsoft.com/azure/bastion/bastion-overview)

---

## What You Will Learn

In this hands-on lab you will set up an on-premises Kubernetes cluster, connect it to Azure Arc, and explore the enterprise capabilities that Arc unlocks — all from your own machine.

By the end of this lab you will be able to:

- Deploy infrastructure with Azure Developer CLI (AZD) and Bicep
- Install a lightweight K3s cluster and connect it to Azure Arc
- Deploy containers to a remote cluster without SSH or VPN (Cluster Connect)
- Apply governance policies across clusters with Azure Policy
- Enable security monitoring with Microsoft Defender for Containers
- Set up centralized observability with Container Insights
- Configure GitOps with Flux v2 for automated deployments
- Query your entire Kubernetes fleet with Azure Resource Graph
- Use Microsoft Copilot in Azure for natural-language cluster management

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Azure Cloud                                  │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │                Azure Arc Control Plane                      │    │
│  │                                                             │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │    │
│  │  │ GitOps   │  │ Policy   │  │ Defender │  │ Monitor  │     │    │
│  │  │ (Flux)   │  │ (OPA)    │  │ Security │  │ Insights │     │    │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘     │    │
│  │       │             │             │             │           │    │
│  │       └─────────────┴───────┬─────┴─────────────┘           │    │
│  │                             │                               │    │
│  │               ┌─────────────┴─────────────┐                 │    │
│  │               │   Arc Connected Cluster   │                 │    │
│  │               │   (control plane proxy)   │                 │    │
│  │               └─────────────┬─────────────┘                 │    │
│  └─────────────────────────────┼───────────────────────────────┘    │
│                                │                                    │
│  ┌──────────────────┐          │         ┌──────────────────┐       │
│  │ Log Analytics    │──────────┤         │ Resource Graph   │       │
│  │ Workspace        │          │         │ (Inventory)      │       │
│  └──────────────────┘          │         └──────────────────┘       │
│                                │                                    │
└────────────────────────────────┼────────────────────────────────────┘
                                 │ Outbound HTTPS (443)
                                 │ (agent-initiated, no inbound needed)
                                 │
┌────────────────────────────────┴─────────────────────────────────────┐
│                   "On-Premises" (Azure VM)                           │
│                                                                      │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │                    K3s Cluster (Rancher)                     │   │
│   │                                                              │   │
│   │   ┌──────────┐  ┌──────────┐  ┌──────────┐                   │   │
│   │   │ Arc      │  │ Flux     │  │ Your     │                   │   │
│   │   │ Agents   │  │ Agent    │  │ Workloads│                   │   │
│   │   └──────────┘  └──────────┘  └──────────┘                   │   │
│   │                                                              │   │
│   └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Lab Outline

| #   | Exercise                                   | Duration    | Type              |
| --- | ------------------------------------------ | ----------- | ----------------- |
| 0   | **Introduction & Architecture**            | 5 min       | Read              |
| 1   | **Deploy Infrastructure (AZD + Bicep)**      | 10 min      | Hands-on          |
| 2   | **SSH & Install K3s (Rancher)**            | 10 min      | Hands-on          |
| 3   | **Arc Onboarding**                         | 10 min      | Hands-on          |
| 4   | **Deploy Container from Azure**            | 10 min      | Hands-on          |
| 5   | **Governance & Compliance (Azure Policy)** | 10 min      | Hands-on          |
| 6   | **Microsoft Defender for Containers**      | 5 min       | Hands-on + Portal |
| 7   | **Monitoring & Observability**             | 10 min      | Hands-on + Portal |
| 8   | **GitOps with Flux**                       | 10 min      | Hands-on          |
| 9   | **Inventory Management**                   | 5 min       | Hands-on          |
| 10  | **Service Mesh on Arc**                    | 15 min      | Hands-on          |
| 11  | **Copilot for Azure**                      | 5 min       | Portal            |
| —   | **Cleanup**                                | 5 min       | Hands-on          |
|     | **Total**                                  | **~110 min**|                   |

---

## Prerequisites — Set Up Your Environment

Before starting the exercises, prepare your environment. Ideally, run through these steps the day before so the infrastructure is ready when you begin.

```bash
# 1. Clone this repo
git clone https://github.com/ewouds/arc_k8s_labo.git && cd arc_k8s_labo

# 2. Initialize AZD
azd init

# 3. Run the prerequisites check to verify all tools are installed
bash scripts/sh/00-prereqs.sh      # Linux/WSL/Git Bash
# .\scripts\ps1\00-prereqs.ps1    # PowerShell

# 4. Deploy infrastructure (takes ~5 min)
azd up
#   Environment name: arcworkshop
#   Location: westeurope
#   VM password: <choose a strong password>
#   deployAks: -> answer 'true' if you want the optional AKS cluster (Exercise 9)

# 5. Note the outputs — you'll need the VM IP throughout the lab
azd env get-values
```

> **Tip:** Infrastructure deployment takes ~5 minutes (~10 if you include the optional AKS cluster). If you're short on time, deploy it before starting the lab so you can jump straight into the exercises.
>
> **Optional AKS cluster:** During `azd up` you will be asked whether to deploy an optional AKS cluster (`deployAks`). This is only used in Exercise 9 (Inventory Management) for side-by-side Resource Graph queries comparing Arc and AKS. It deploys a single-node Standard_B2s cluster with a sample workload -- extra cost: ~EUR 0.10/hour.

<details>
<summary><strong>Alternative: deploy with az CLI + Bicep (if AZD is not available)</strong></summary>

If you cannot install AZD, you can deploy directly with the Azure CLI:

```bash
# Deploy infrastructure
az deployment sub create \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json \
  --parameters vmAdminPassword='<choose a strong password>'
#   Optional: add --parameters deployAks=true for the AKS cluster (Exercise 9)

# Retrieve outputs
az deployment sub show \
  --name main \
  --query properties.outputs -o json
```

Whenever the workshop mentions `azd env get-values`, use the `az deployment sub show` command above instead.

</details>

---

## Exercise 0: Introduction & Architecture (5 min)

Before diving in, take a moment to understand **what Azure Arc is** and **why it matters** for Kubernetes.

### What is Azure Arc?

- Azure Arc extends the Azure control plane to **any infrastructure**: on-prem, edge, multi-cloud
- It is **not a data plane migration** — your workloads stay where they are
- Azure Arc for Kubernetes enables managing **any CNCF-compliant K8s cluster** from Azure

### Why Arc-enabled Kubernetes?

- **One management plane** for all clusters (AKS, EKS, GKE, on-prem, edge)
- **Consistent policies** — Azure Policy works identically on AKS and Arc
- **Central overview** — all clusters in Azure Resource Graph
- **GitOps native** — Flux v2 is built-in, not an add-on
- **No inbound firewall rules required** — agents make outbound HTTPS connections

### What you'll build today

- Set up a K3s cluster in a VM (simulates on-prem)
- Connect that cluster to Azure Arc
- Explore all enterprise features: Policy, Defender, Monitoring, GitOps
- Everything automated with Infrastructure as Code (Bicep + AZD)

> **Key takeaway:** _"Arc brings Azure to your infrastructure, not your infrastructure to Azure."_

---

## Exercise 1: Deploy Infrastructure -- AZD + Bicep (10 min)

In this exercise you will deploy the lab infrastructure using Azure Developer CLI (AZD) and Bicep templates.

### What you're deploying

- An Ubuntu VM that simulates your "on-premises server"
- A VNet with NSG (SSH, HTTPS, K8s API open)
- A Log Analytics Workspace (for monitoring later)
- *(Optional)* An AKS cluster for inventory comparison (Exercise 9)
- Everything via **Bicep** and **Azure Developer CLI (AZD)**

### Why AZD?

- AZD is the developer-first CLI for Azure
- Combines infra provisioning (Bicep) with app deployment
- Simple `azd up` to deploy everything
- Environment management (dev, staging, prod)
- Built-in hooks for pre/post provisioning

### Steps

**Step 1 — Explore the project structure:**

```bash
tree .  # or: Get-ChildItem -Recurse (PowerShell)
```

Take a look at the key files:

| File                               | Purpose                                                      |
| ---------------------------------- | ------------------------------------------------------------ |
| `azure.yaml`                       | AZD project definition -- points to infra/main.bicep          |
| `infra/main.bicep`                 | Main orchestrator — subscription scope, creates RG + modules |
| `infra/modules/network.bicep`      | VNet, Subnet, NSG, Public IP                                 |
| `infra/modules/vm.bicep`           | Ubuntu 22.04 VM with password auth                           |
| `infra/modules/loganalytics.bicep` | Log Analytics workspace                                      |
| `infra/modules/aks.bicep`          | (Optional) AKS cluster for inventory comparison              |

**Step 2 — Review the Bicep templates:**

```bash
# Open main.bicep and look at:
#   - targetScope = 'subscription'
#   - parameters (environmentName, location, vmAdminPassword)
#   - module references
#   - outputs (VM IP, SSH command)
cat infra/main.bicep

# Open a module (e.g., network.bicep) and look at:
#   - NSG rules (SSH 22, HTTPS 443, K8s API 6443)
#   - Public IP with DNS label
cat infra/modules/network.bicep
```

**Step 3 -- Deploy the infrastructure (skip if already deployed during prerequisites):**

```bash
azd up
#    Enter environment name: arcworkshop
#    Select location: West Europe
#    Enter VM password: <strong-password>
```

<details>
<summary><strong>Alternative: az CLI + Bicep</strong></summary>

```bash
az deployment sub create \
  --location westeurope \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json \
  --parameters vmAdminPassword='<strong-password>'
```

</details>

**Step 4 -- Retrieve the outputs:**

```bash
azd env get-values
#    VM_PUBLIC_IP=x.x.x.x
#    SSH_COMMAND=ssh azureuser@x.x.x.x
```

<details>
<summary><strong>Alternative: az CLI</strong></summary>

```bash
az deployment sub show \
  --name main \
  --query properties.outputs -o json
```

</details>

> **Key takeaway:** _"With AZD + Bicep your entire lab environment is reproducible. One command, everything is ready."_

---

## Exercise 2: SSH & Install K3s (10 min)

In this exercise you will SSH into the VM and install K3s — a lightweight, production-grade Kubernetes distribution.

### What is K3s?

- Lightweight Kubernetes distribution by **Rancher (SUSE)**
- Fully CNCF-certified — 100% compatible with standard K8s
- Single binary of ~70MB (vs. ~700MB+ for standard kubeadm)
- Ideal for **edge, IoT, development, resource-constrained** environments
- Includes everything: containerd, Flannel CNI, CoreDNS, Traefik, local-path storage

### Why K3s for this lab?

- Fast installation (~30 seconds)
- Low resource requirements (512MB RAM, 1 CPU)
- Perfect for simulating on-prem / edge scenarios
- Azure Arc works with **any** CNCF K8s distribution

### Steps

**Step 1 — SSH into the VM:**

```bash
ssh azureuser@<VM_PUBLIC_IP>
# (password from azd deployment)
```

**Step 2 — Run the installation script:**

> The script `02-install-k3s.sh` automates all installation steps. The individual commands are shown below for reference so you understand what happens under the hood.

```bash
bash 02-install-k3s.sh
```

**What does the script do?**

1. **Update system** — `apt-get update && upgrade` for the latest security patches
2. **Install K3s** — downloads and installs K3s via the official install script (`curl -sfL https://get.k3s.io | sh -`). This includes: containerd, Flannel CNI, CoreDNS, Traefik, and local-path storage
3. **Configure kubectl** — copies the K3s kubeconfig to `~/.kube/config` so `kubectl` works immediately for the current user
4. **Verify installation** — runs verification commands:

```bash
# These commands are executed automatically by the script:
kubectl get nodes          # Should show 1 node (Ready)
kubectl get pods -A        # System pods (coredns, traefik, etc.)
kubectl cluster-info       # Cluster endpoint info
k3s --version              # K3s version
```

### Things to notice

- K3s runs as a systemd service: `systemctl status k3s`
- Everything in one process: API server, scheduler, controller manager, kubelet
- SQLite instead of etcd for single-node (etcd available for HA)
- Traefik ingress controller is installed by default

> **Key takeaway:** _"In 30 seconds you have a production-ready Kubernetes cluster. It runs fully standalone, independent from Azure."_

---

## Exercise 3: Arc Onboarding (10 min)

In this exercise you will connect the K3s cluster to Azure Arc — the central step that unlocks all Azure management capabilities.

### What happens during onboarding?

- The `az connectedk8s connect` command installs Arc agents in the cluster
- Agents are deployed in the `azure-arc` namespace
- The agents make an **outbound HTTPS** connection to Azure (no inbound ports needed!)
- Azure creates a `connectedClusters` resource in your resource group

### Arc Agent components

| Agent                       | Function                                    |
| --------------------------- | ------------------------------------------- |
| `clusterconnect-agent`      | Reverse proxy for cluster access from Azure |
| `guard-agent`               | Azure RBAC enforcement                      |
| `cluster-metadata-operator` | Cluster metadata sync                       |
| `config-agent`              | GitOps/extensions configuration             |
| `controller-manager`        | Lifecycle management of agents              |

### Security model

- Agents initiate all connections (outbound only)
- Communication via Azure Relay (or direct endpoints)
- Managed Identity per cluster
- No credentials stored in Azure

### Steps

**Step 1 — SSH into the VM (if not already connected):**

```bash
ssh azureuser@<VM_PUBLIC_IP>
```

**Step 2 — Run the onboarding script:**

> The script `03-arc-onboard.sh` automates all the steps below. The individual commands are shown for reference.

```bash
bash 03-arc-onboard.sh
```

**What does the script do?**

1. **Install Azure CLI** — installs the Azure CLI on the VM via the official install script (`curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`)
2. **Log in to Azure** — starts a device code flow login (`az login --use-device-code`) since you're working remotely via SSH. You use an interactive login here because you're onboarding **a single cluster** manually.
   > **At scale:** to onboard tens or hundreds of clusters, use a **Service Principal** (`az login --service-principal`) or **Managed Identity**, combined with automation via Azure CLI scripts, Ansible, or CI/CD pipelines. See: [Arc K8s onboarding with Service Principal](https://learn.microsoft.com/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli#connect-using-a-service-principal) · [At-scale onboarding](https://learn.microsoft.com/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli#connect-a-large-number-of-clusters)
3. **Install connectedk8s extension** — adds the Arc K8s CLI extension (`az extension add --name connectedk8s`)
4. **Set variables** — configures resource group, cluster name, and location
5. **Connect cluster to Azure Arc** — runs the actual onboarding command:

```bash
# This command is automatically executed by the script:
az connectedk8s connect \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

6. **Verification** — checks whether onboarding was successful:

```bash
# These commands are automatically executed by the script:
az connectedk8s show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP -o table
kubectl get pods -n azure-arc
kubectl get deployments -n azure-arc
```

### Verify in the Azure Portal

After the script completes, open the Azure Portal and navigate to:

**Resource Group** → **arc-k3s-cluster**

Check these things:

- Connected cluster resource with status **"Connected"**
- Kubernetes version and node count are automatically synchronized
- The cluster is now visible in Azure Resource Graph
- Tags, RBAC, and Activity Log work just like native Azure resources

> **Key takeaway:** _"With one command, your on-prem cluster is part of Azure. No VPN, no inbound firewall rules, no agent management."_

---

## Exercise 4: Deploy Container from Azure (10 min)

In this exercise you will deploy a container to the on-prem cluster **without SSH or VPN** — using Azure Arc Cluster Connect.

### What is Cluster Connect?

- Access to the K8s API **via Azure**, without a direct network connection
- Works via the `az connectedk8s proxy` command
- Ideal for secure access without VPN or ExpressRoute
- Uses Azure RBAC for authorization

### What you'll do

- From your local machine, via Azure, deploy a container to the Arc cluster
- **This is the core value of Arc:** you don't need SSH, VPN, or direct network access — Azure acts as a secure proxy to your cluster

### Steps

> Run these commands on your **local machine** (not the VM).

**Step 1 — Start the Cluster Connect proxy and deploy the application:**

```bash
# PowerShell:
.\scripts\ps1\04-deploy-container.ps1

# Bash:
bash scripts/sh/04-deploy-container.sh
```

The script will:

1. Open a tunnel via Azure to your Arc cluster (`az connectedk8s proxy`)
2. Verify that `kubectl` works locally through the tunnel
3. Deploy `k8s/demo-app.yaml` (an nginx demo application)
4. Wait for the pods to become ready

```bash
# Once the proxy is running, you can also run commands manually:
kubectl get nodes
kubectl get pods -n demo
```

> **Why is this special?** Your laptop has no direct network connection to the VM or the cluster. All communication flows through Azure Arc as a reverse proxy. In a production environment, this means: no VPN needed, no ports to open, and access controlled via Azure RBAC.

**Step 2 — Deploy a second container via the Azure Portal:**

The script will pause and guide you through deploying a second application directly from the Azure Portal:

1. Go to the **Azure Portal** → your Arc cluster (`arc-k3s-cluster`)
2. Navigate to **Kubernetes resources** → **Workloads**
3. Click **+ Create** at the top → **Apply with YAML**
4. Paste the YAML below and click **Add**:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-arc
  namespace: demo
  labels:
    app: hello-arc
    environment: workshop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hello-arc
  template:
    metadata:
      labels:
        app: hello-arc
        environment: workshop
    spec:
      containers:
        - name: hello-arc
          image: httpd:2.4-alpine
          ports:
            - containerPort: 80
              name: http
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: hello-arc
  namespace: demo
  labels:
    app: hello-arc
    environment: workshop
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: 80
      protocol: TCP
      name: http
  selector:
    app: hello-arc
```

5. Wait for the pod to be `Running` — verify in **Workloads** or press Enter in the script to run verification:

```bash
kubectl get pods -n demo
# Expected: nginx-demo pods + hello-arc pod
```

### Verify in the Azure Portal

Under **Kubernetes resources** check:

- **Two applications** (nginx-demo + hello-arc) running on the on-prem cluster
- You can **edit and apply YAML directly from the portal**
- Namespace filtering, search, and live status
- This works identically for Arc AND AKS clusters

> **Key takeaway:** _"Azure gives you full visibility and control over workloads, regardless of where the cluster runs — via CLI and via the portal."_

---

## Exercise 5: Governance & Compliance — Azure Policy (10 min)

In this exercise you will apply Azure Policy to your Arc-connected cluster, enforcing the same governance rules you use for native Azure resources.

### What is Azure Policy for Kubernetes?

- The same Azure Policy engine you know for Azure resources
- Uses **OPA Gatekeeper** under the hood for K8s enforcement
- Works identically on AKS and Arc-connected clusters
- **Audit** mode (report) or **Deny** mode (block)

### What you'll configure

1. **No privileged containers** — Prevent containers with root-level access
2. **Require labels** — Enforce that pods have an `environment` label
3. **Allowed registries** — Only allow images from trusted registries

### Why this matters

- Consistent security baseline across ALL clusters
- Compliance reporting in one dashboard
- Automatic enforcement — no manual reviews needed
- Audit trail for regulations (SOC2, ISO27001, etc.)

### Steps

Run these commands from your **local machine**:

```bash
# 1. Install the Azure Policy extension on the Arc cluster
az k8s-extension create \
  --name azurepolicy \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  --extension-type Microsoft.PolicyInsights

# 2. Wait for extension to be ready
az k8s-extension show \
  --name azurepolicy \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  -o table

# 3. Get the cluster resource ID
CLUSTER_ID=$(az connectedk8s show \
  -n arc-k3s-cluster \
  -g rg-arcworkshop \
  --query id -o tsv)

# 4. Assign policy: No privileged containers
az policy assignment create \
  --name "no-privileged-containers" \
  --display-name "[Arc Workshop] No privileged containers" \
  --policy "95edb821-ddaf-4404-9732-666045e056b4" \
  --scope "$CLUSTER_ID" \
  --params '{"effect": {"value": "Deny"}}'

# 5. Try to deploy a privileged pod — it should be DENIED!
ssh azureuser@<VM_IP> "kubectl apply -f ~/privileged-pod.yaml"
# Expected output: Error from server (Forbidden): admission webhook denied the request
```

> **Important:** Policies need **15–30 minutes** to sync to the cluster via Gatekeeper. The privileged pod test (step 5) will only fail **after** Gatekeeper has synced the constraints.
>
> **How to check if policies are ready:**
>
> ```bash
> # Check if Gatekeeper constraints exist (empty = not yet synced)
> kubectl get constraints
> kubectl get constrainttemplates
>
> # Check Gatekeeper pods are running
> kubectl get pods -n gatekeeper-system
> ```
>
> If `kubectl get constraints` returns results, the policies are active and the privileged pod will be denied. While waiting, continue with the next exercises and come back to test later.

### Verify in the Azure Portal

- **Arc cluster → Policies** — see assignments and compliance
- **Azure Policy → Compliance** — filter by resource group for a compliance dashboard
- Notice the Gatekeeper pods in the `gatekeeper-system` namespace
- You can also use **initiative definitions** for groups of policies

> **Key takeaway:** _"One set of policies, enforced everywhere. Whether it's AKS in Azure or K3s on an edge server — same rules, same compliance."_

---

## Exercise 6: Microsoft Defender for Containers (5 min)

In this exercise you will enable Microsoft Defender for Containers on your Arc-connected cluster for runtime threat detection and vulnerability scanning.

### What does Defender offer?

- **Runtime threat detection** — suspicious processes, crypto mining, reverse shells
- **Vulnerability scanning** — CVEs in container images
- **Security recommendations** — best practices for cluster hardening
- **Security alerts** — real-time notifications for threats

### How does it work?

- Defender sensor (DaemonSet) runs on every node
- Sends security data to the Defender backend via Arc
- Combined with Log Analytics for correlation
- Same Defender experience as for AKS

### Steps

```bash
# 1. Enable Defender for Containers plan
az security pricing create --name Containers --tier Standard

# 2. Install Defender extension
az k8s-extension create \
  --name microsoft.azuredefender.kubernetes \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  --extension-type microsoft.azuredefender.kubernetes \
  --configuration-settings "logAnalyticsWorkspaceResourceID=<WORKSPACE_ID>"

# 3. Verify Defender pods are running
ssh azureuser@<VM_IP> "kubectl get pods -n mdc"

# 4. Disable governance policies (if Exercise 5 was completed)
#    The test alert image may be blocked by the allowed-registries policy
#    and the require-labels policy. Disable them temporarily:
.\scripts\ps1\05a-toggle-policies.ps1 disable   # PowerShell
# OR: bash scripts/sh/05a-toggle-policies.sh disable   # Bash

# 5. Trigger a test security alert
ssh azureuser@<VM_IP> "kubectl run defender-test \
  --image=mcr.microsoft.com/aks/security/test-alert \
  --restart=Never \
  --labels=environment=workshop"

# 6. Cleanup test pod & re-enable policies
ssh azureuser@<VM_IP> "kubectl delete pod defender-test --ignore-not-found"
.\scripts\ps1\05a-toggle-policies.ps1 enable   # PowerShell
# OR: bash scripts/sh/05a-toggle-policies.sh enable   # Bash
```

> **Note:** The test alert takes approximately **30 minutes** to appear in the Security Alerts blade.

### Verify in the Azure Portal

Navigate through:

- **Defender for Cloud → Workload protections → Containers**
- **Defender for Cloud → Security alerts** (test alert appears after ~30 min)
- **Defender for Cloud → Recommendations** (filter: connectedClusters)
- **Arc cluster → Security** blade
- Check the **Secure Score** impact

> **Key takeaway:** _"Enterprise-grade security for any K8s cluster, managed from Defender for Cloud. Same protection as AKS, regardless of location."_

---

## Exercise 7: Monitoring & Observability (10 min)

In this exercise you will enable Container Insights to gain the same monitoring experience you get with AKS — centralized logs, metrics, and dashboards.

### What is Container Insights?

- Same monitoring experience as AKS
- CPU, memory, network metrics per node/pod/container
- Container logs centralized in Log Analytics
- Pre-built workbooks and dashboards
- KQL queries for in-depth analysis

### How does it work?

- Azure Monitor agent (AMA) as extension on the Arc cluster
- Data is sent to Log Analytics
- Perf data, inventory, and logs — all correlated

### Steps

```bash
# 1. Install Container Insights extension
az k8s-extension create \
  --name azuremonitor-containers \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  --extension-type Microsoft.AzureMonitor.Containers \
  --configuration-settings "logAnalyticsWorkspaceResourceID=<WORKSPACE_ID>"

# 2. Wait ~5-10 minutes for data to flow
```

### Explore in the Azure Portal

Once data starts flowing, explore these areas:

**Arc cluster → Insights:**

- **Cluster** tab: node CPU/memory heatmap
- **Nodes** tab: per-node resource utilization
- **Controllers** tab: deployment health
- **Containers** tab: individual container metrics

**Arc cluster → Logs — try these KQL queries:**

```kql
// Pod inventory
KubePodInventory
| where ClusterName == "arc-k3s-cluster"
| summarize count() by PodStatus, Namespace
| render piechart

// Container CPU usage
Perf
| where ObjectName == "K8SContainer"
| where CounterName == "cpuUsageNanoCores"
| summarize avg(CounterValue) by InstanceName, bin(TimeGenerated, 5m)
| render timechart
```

**Arc cluster → Workbooks:** pre-built workbooks for K8s monitoring

**Azure Monitor → Containers:** multi-cluster view (Arc + AKS together!)

### Things to notice

- Multi-cluster monitoring: Arc AND AKS clusters side by side
- Custom alerts based on KQL queries
- Workbooks are shareable and customizable
- Data retention configurable (30–730 days)

> **Key takeaway:** _"One monitoring platform for all your clusters. Same KQL queries, same dashboards, whether it's Arc or AKS."_

---

## Exercise 8: GitOps with Flux (10 min)

In this exercise you will configure GitOps on the Arc cluster using Flux v2 — making Git the single source of truth for your cluster state.

### What is GitOps?

- **Git as the single source of truth** for cluster configuration
- Pull-based model: Flux in the cluster pulls changes
- Automatic reconciliation: drift is automatically corrected
- Audit trail via Git history

### Flux v2 on Azure Arc

- CNCF graduated project, natively integrated into Azure
- Supports Kustomize and Helm
- Managed via Azure (`az k8s-configuration flux`)
- Compliance status visible in Azure Portal
- Works identically on AKS and Arc

### Workflow

```
You → Git Push → Flux detects → Flux applies → Cluster state updated
                                                      ↓
                                         Azure shows compliance ✅
```

### Steps

```bash
# 1. Install Flux extension
az k8s-extension create \
  --name flux \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  --extension-type microsoft.flux

# 2. Create a GitOps configuration
az k8s-configuration flux create \
  --name demo-gitops \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  --namespace gitops-demo \
  --scope cluster \
  --url https://github.com/ewouds/arc_k8s_labo \
  --branch master \
  --kustomization name=cluster-config path=./gitops prune=true

# 3. Check sync status
az k8s-configuration flux show \
  --name demo-gitops \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  -o table

# 4. On the VM, verify the deployments
ssh azureuser@<VM_IP> "kubectl get all --all-namespaces | grep -i gitops"
```

### Verify in the Azure Portal

Navigate to **Arc cluster → GitOps** and check:

- Configuration name and source repo
- Compliance state (Compliant / Non-compliant)
- Kustomization details
- Last sync time

### Try it yourself

Make a change to the Git repo (e.g., update a replica count) and watch Flux detect and apply it. Flux checks for changes at a default 10-minute interval, or you can force a sync:

```bash
az k8s-configuration flux update ...
```

### Things to notice

- Flux runs in the `flux-system` namespace
- Private Git repos are supported (SSH keys, tokens)
- Helm charts are also supported
- Multi-tenancy: namespace-scoped vs cluster-scoped configs

> **Key takeaway:** _"GitOps via Azure Arc: centralized management, automatic deployment, full audit trail. Configuration IS code."_

---

## Exercise 9: Inventory Management (5 min)

In this exercise you will use Azure Resource Graph to query your entire Kubernetes fleet in real time — Arc-connected and AKS clusters alike.

### What is Azure Resource Graph?

- Instant queries across ALL Azure resources (incl. Arc clusters)
- Cross-subscription, cross-tenant queries
- Sub-second response times, even with thousands of resources
- Perfect for compliance reporting and dashboards

### Typical use cases

- How many clusters are running an outdated K8s version?
- Which clusters are missing the monitoring extension?
- Compliance status overview per cluster
- Clusters that are offline (disconnected)

### Steps

> **Optional AKS cluster for side-by-side comparison:**
>
> If you chose `deployAks = true` during `azd up` (or `--parameters deployAks=true` with az CLI), an AKS cluster with a `hello-aks` sample workload is already running in your resource group. The queries below will show both cluster types side by side.
>
> If you did **not** enable AKS, Query 4 below will only show your Arc cluster. You can re-run `azd up` with `deployAks = true` (or re-deploy with `--parameters deployAks=true`) at any time to add the AKS cluster.

```bash
# 1. Query all Arc-connected clusters
az graph query -q "
  resources
  | where type =~ 'microsoft.kubernetes/connectedclusters'
  | project name, resourceGroup, location,
            k8sVersion=properties.kubernetesVersion,
            status=properties.connectivityStatus
"

# 2. Compare Arc + AKS clusters side by side
#    (Shows both cluster types if the optional AKS was deployed)
az graph query -q "
  resources
  | where type in (
      'microsoft.kubernetes/connectedclusters',
      'microsoft.containerservice/managedclusters')
  | extend clusterType = iff(type contains 'connected', 'Arc', 'AKS')
  | project name, clusterType, location,
            k8sVersion=properties.kubernetesVersion
" -o table
```

### Verify in the Azure Portal

- **Azure Resource Graph Explorer** — run queries interactively, pin to dashboards, export to CSV
- **Arc → Kubernetes clusters** — unified list of all Arc clusters with filtering, sorting, and tag management

> **Key takeaway:** _"Resource Graph gives you instant visibility across your entire Kubernetes fleet. Arc + AKS, one query."_

---

## Exercise 10: Service Mesh on Arc (15 min)

In this exercise you will deploy the **Linkerd** service mesh on your Arc-connected cluster and manage it exclusively through Azure Arc capabilities: **GitOps**, **Container Insights**, **Azure Policy**, and **Cluster Connect**.

### Why a Service Mesh?

| Problem | Mesh Solution |
| --- | --- |
| Unencrypted pod-to-pod traffic | **mTLS** — automatic mutual TLS between all services |
| No traffic control | **Traffic Splitting** — canary deployments with weighted routing |
| Limited observability | **Golden metrics** — latency, success rate, throughput per route |
| No uniform policy | **Azure Policy** — enforce sidecar injection across clusters |

### Why Linkerd?

- **Lightweight:** ~50 MB RAM (vs. Istio ~500 MB+). Perfect for K3s / edge.
- **CNCF Graduated:** production-grade, battle-tested.
- **SMI compatible:** uses the Service Mesh Interface standard for traffic splitting.
- **Fast install:** < 60 seconds on a K3s cluster.

### Architecture

```
┌─────────────────────────────────────────────────┐
│  mesh-demo namespace (linkerd.io/inject=enabled) │
│                                                  │
│  ┌──────────────┐      ┌──────────────────┐     │
│  │  frontend     │─────▶│  backend (v1+v2) │     │
│  │  nginx proxy  │ mTLS │  http-echo       │     │
│  │  + sidecar    │      │  + sidecar       │     │
│  └──────────────┘      └──────────────────┘     │
│                              │                   │
│                    ┌─────────┴─────────┐        │
│                    │   TrafficSplit     │        │
│                    │  80% v1 / 20% v2  │        │
│                    └───────────────────┘        │
└─────────────────────────────────────────────────┘
```

### Step 1 — Install Linkerd Service Mesh

```bash
# Install Linkerd CLI
curl -fsL https://run.linkerd.io/install | sh
export PATH=$HOME/.linkerd2/bin:$PATH

# Pre-flight check
linkerd check --pre

# Install CRDs + control plane
linkerd install --crds | kubectl apply -f -
linkerd install | kubectl apply -f -

# Verify installation
linkerd check
```

<details>
<summary>💡 PowerShell alternative</summary>

```powershell
# Download for Windows (or use: scoop install linkerd)
$v = (Invoke-RestMethod "https://api.github.com/repos/linkerd/linkerd2/releases/latest").tag_name
Invoke-WebRequest "https://github.com/linkerd/linkerd2/releases/download/$v/linkerd2-cli-$v-windows.exe" -OutFile linkerd.exe

.\linkerd.exe check --pre
.\linkerd.exe install --crds | kubectl apply -f -
.\linkerd.exe install | kubectl apply -f -
.\linkerd.exe check
```
</details>

> **🔑 Arc added value:** You don't need SSH access to the cluster. Use `az connectedk8s proxy` (Cluster Connect) to run these commands from your laptop through Azure.

### Step 2 — Deploy Mesh Demo App

Deploy a two-service application: **frontend** (nginx reverse proxy) → **backend** (http-echo). Both get Linkerd sidecar proxies automatically.

```bash
# Create the namespace (has linkerd.io/inject=enabled label)
kubectl apply -f k8s/mesh-demo/namespace.yaml

# Deploy frontend + backend
kubectl apply -f k8s/mesh-demo/backend-v1.yaml
kubectl apply -f k8s/mesh-demo/backend-service.yaml
kubectl apply -f k8s/mesh-demo/frontend.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app=backend -n mesh-demo --timeout=120s
kubectl wait --for=condition=ready pod -l app=frontend -n mesh-demo --timeout=120s

# Verify: each pod should have 2 containers (app + linkerd-proxy)
kubectl get pods -n mesh-demo
```

Expected output:
```
NAME                          READY   STATUS    RESTARTS   AGE
backend-v1-xxxxx-yyyyy        2/2     Running   0          30s
backend-v1-xxxxx-zzzzz        2/2     Running   0          30s
frontend-xxxxx-yyyyy          2/2     Running   0          30s
```

The `2/2` confirms the Linkerd sidecar proxy was injected.

> **🔑 Arc added value:** In production, you would push these manifests to Git and let **Flux** (Exercise 8) deploy them. The GitOps files are ready in `gitops/apps/mesh-demo.yaml`.

### Step 3 — Verify mTLS (Zero-Trust)

Linkerd automatically encrypts ALL pod-to-pod traffic with mutual TLS. No code changes needed.

```bash
# Check that sidecars are injected
kubectl get pod -l app=frontend -n mesh-demo -o jsonpath='{.items[0].spec.containers[*].name}'
# Output: frontend linkerd-proxy

# Test service-to-service communication
FRONTEND_POD=$(kubectl get pod -l app=frontend -n mesh-demo -o jsonpath='{.items[0].metadata.name}')
kubectl exec $FRONTEND_POD -n mesh-demo -c frontend -- wget -qO- http://backend.mesh-demo.svc.cluster.local/
# Output: Hello from backend-v1 🟢
```

Optionally, install `linkerd-viz` for a detailed mTLS dashboard:

```bash
linkerd viz install | kubectl apply -f -
linkerd viz stat deploy -n mesh-demo
```

> **Key takeaway:** _"Every call between services is now encrypted with mTLS — zero-trust networking without changing a single line of application code."_

### Step 4 — Observe via Container Insights

Because Container Insights (Exercise 7) is already installed, Azure Monitor automatically captures the Linkerd sidecar metrics.

**In the Azure Portal:**
1. Navigate to **Arc cluster → Insights → Containers**
2. Filter by namespace: `mesh-demo`
3. You'll see **2 containers per pod**: the app container + `linkerd-proxy`

**KQL query** to find sidecar containers:
```kql
ContainerInventory
| where Namespace == "mesh-demo"
| where ContainerName contains "linkerd"
| summarize count() by Computer, ContainerName
```

> **🔑 Arc added value:** _"Same Azure Monitor dashboards you use for AKS. The mesh sidecar metrics just appear — no extra configuration."_

### Step 5 — Canary Deployment via Traffic Splitting

Deploy a second version of the backend and split traffic using the **SMI TrafficSplit** resource:

```bash
# Deploy backend-v2 + TrafficSplit (80/20)
kubectl apply -f k8s/mesh-demo/backend-v2.yaml
kubectl apply -f k8s/mesh-demo/traffic-split.yaml

# Wait for v2
kubectl wait --for=condition=ready pod -l app=backend,version=v2 -n mesh-demo --timeout=120s

# Test: send 10 requests and observe the split
for i in $(seq 1 10); do
  kubectl exec $FRONTEND_POD -n mesh-demo -c frontend -- wget -qO- http://backend.mesh-demo.svc.cluster.local/
done
```

Expected output (~80% v1, ~20% v2):
```
Hello from backend-v1 🟢
Hello from backend-v1 🟢
Hello from backend-v2 🔵 (canary)
Hello from backend-v1 🟢
Hello from backend-v1 🟢
...
```

> **🔑 Arc added value:** In a GitOps workflow, you push the `TrafficSplit` manifest to Git → Flux applies it automatically. The canary configuration in `gitops/apps/mesh-canary.yaml` is ready for this.

### Step 6 — Enforce Mesh via Azure Policy

Azure Policy (Exercise 5) can enforce that all pods in mesh-enabled namespaces have the sidecar annotation:

```bash
# The namespace already has the injection label
kubectl get namespace mesh-demo --show-labels
# linkerd.io/inject=enabled
```

In production, you would create an Azure Policy that:
- **Audits** pods without `linkerd.io/inject` annotation
- **Denies** deployments to mesh namespaces without sidecars
- **Reports** compliance in the Azure Portal (Policy → Compliance)

> **🔑 Arc added value:** _"One policy definition, applied across all your Arc + AKS clusters. Mesh governance at scale."_

### Summary: Arc Added Value for Service Mesh

| Arc Capability | What It Does for Your Mesh |
| --- | --- |
| **GitOps (Flux)** | Deploy mesh config via Git — no direct cluster access needed |
| **Container Insights** | Sidecar metrics visible in Azure Monitor — same dashboards as AKS |
| **Azure Policy** | Enforce sidecar injection across ALL clusters from one place |
| **Cluster Connect** | Manage the mesh remotely via `az connectedk8s proxy` |
| **Resource Graph** | Query mesh status across your entire fleet in seconds |

> **Key takeaway:** _"The service mesh runs on your cluster, but Azure Arc gives you the management plane — GitOps, monitoring, policy, and remote access. One consistent experience across on-prem, edge, and multi-cloud."_

---

## Exercise 11: Copilot for Azure (5 min)

In this exercise you will use Microsoft Copilot in the Azure Portal to manage your Arc cluster with natural language.

### What is Copilot in Azure?

- Natural language interface for Azure management
- Integrated into the Azure Portal
- Understands the context of your current resource

### Steps

1. Open the **Azure Portal**
2. Click the **Copilot icon** in the top bar
3. Navigate to your Arc cluster resource

Try these prompts:

| Prompt                                                                 | What Copilot does                             |
| ---------------------------------------------------------------------- | --------------------------------------------- |
| _"What is the connectivity status of this cluster?"_                   | Shows cluster status, K8s version, node count |
| _"Show me the policies assigned to this cluster"_                      | Lists policy assignments and compliance       |
| _"Generate a KQL query to find all error logs from my containers"_     | Generates a ContainerLogV2 query              |
| _"What security recommendations does Defender have for this cluster?"_ | Shows Defender recommendations                |
| _"How do I set up GitOps for this cluster?"_                           | Walks through the configuration steps         |

> **Key takeaway:** _"Copilot makes Azure Arc even more accessible. Natural language, context-aware, and integrated into your workflow."_

---

## Cleanup

When you're done with the lab, clean up the resources to avoid ongoing costs:

```bash
# Option 1: AZD (recommended -- removes everything)
azd down --purge --force

# Option 2: Cleanup script
bash scripts/sh/99-cleanup.sh      # or: .\scripts\ps1\99-cleanup.ps1

# Option 3: Delete the resource group directly
az group delete --name rg-arcworkshop --yes --no-wait
```

> If you deployed the optional AKS cluster in Exercise 9, also delete its resource group:
>
> ```bash
> az group delete --name rg-arcworkshop-aks --yes --no-wait
> ```

---

## Summary & Key Takeaways

Congratulations! You've completed the Azure Arc-enabled Kubernetes hands-on lab. Here's what you accomplished:

| Capability              | What You Did                                                     |
| ----------------------- | ---------------------------------------------------------------- |
| **Onboarding**          | `az connectedk8s connect` — one command to connect any K8s       |
| **Workload Deployment** | Deployed containers via CLI, Cluster Connect, and Azure Portal   |
| **Governance**          | Azure Policy with OPA Gatekeeper — same policies everywhere      |
| **Security**            | Microsoft Defender — runtime protection + vulnerability scanning |
| **Monitoring**          | Container Insights — same dashboards as AKS                      |
| **GitOps**              | Flux v2 — Git as source of truth, managed from Azure             |
| **Inventory**           | Resource Graph — instant queries across your entire fleet        |
| **Service Mesh**        | Linkerd — mTLS, traffic splitting, managed via Arc GitOps        |
| **AI-Assisted**         | Copilot — natural language management                            |

### Core Message

> **Azure Arc brings the Azure management plane to YOUR clusters — not your clusters to Azure.**  
> Same tools, same policies, same monitoring. Regardless of where your Kubernetes runs.

---

## Next Steps

Now that you've seen Azure Arc in action, here are some ideas to explore further:

### Extend Your Lab

- **Multi-cluster:** spin up a second K3s VM and Arc-connect it — see how Resource Graph, Policy, and GitOps scale across clusters
- **Helm + Flux:** set up a Flux HelmRelease to deploy Helm charts via GitOps
- **Private Git repos:** configure Flux with SSH deploy keys or PAT tokens
- **Azure RBAC:** configure granular Azure RBAC roles for namespace-level access
- **Custom policies:** author your own OPA Rego policy and assign it via Azure Policy
- **Azure Monitor alerts:** create KQL-based alerts for container errors or resource spikes

### Production Readiness Checklist

Before using Arc in production, consider:

- [ ] Replace password auth with SSH keys or Azure Bastion
- [ ] Use Service Principals or Managed Identity for Arc onboarding
- [ ] Enable private endpoints for the Arc connection
- [ ] Apply least-privilege RBAC roles (avoid `cluster-admin` for day-to-day use)
- [ ] Configure network segmentation and NSG rules
- [ ] Set data retention policies for Log Analytics
- [ ] Enable Defender for Cloud across all subscriptions

### Certifications & Learning Paths

- [AZ-800: Administer Windows Server Hybrid Core Infrastructure](https://learn.microsoft.com/certifications/exams/az-800) — covers Azure Arc
- [AZ-500: Azure Security Engineer Associate](https://learn.microsoft.com/certifications/exams/az-500) — covers Defender for Cloud
- [Microsoft Learn: Azure Arc learning path](https://learn.microsoft.com/training/paths/manage-hybrid-infrastructure-with-azure-arc/)
- [CNCF: Introduction to GitOps](https://www.cncf.io/blog/2021/09/28/gitops-101-whats-it-all-about/)

---

## References & Useful Links

| Topic | Link |
| --- | --- |
| Azure Arc-enabled Kubernetes docs | [learn.microsoft.com/azure/azure-arc/kubernetes/](https://learn.microsoft.com/azure/azure-arc/kubernetes/) |
| K3s by Rancher | [k3s.io](https://k3s.io/) |
| Azure Policy for Kubernetes | [learn.microsoft.com/.../policy-for-kubernetes](https://learn.microsoft.com/azure/governance/policy/concepts/policy-for-kubernetes) |
| GitOps with Flux v2 | [learn.microsoft.com/.../tutorial-use-gitops-flux2](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2) |
| Container Insights for Arc | [learn.microsoft.com/.../container-insights-enable-arc-enabled-clusters](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-enable-arc-enabled-clusters) |
| Defender for Containers | [learn.microsoft.com/.../defender-for-containers-introduction](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction) |
| Azure Developer CLI (azd) | [learn.microsoft.com/.../azure-developer-cli/](https://learn.microsoft.com/azure/developer/azure-developer-cli/) |
| Azure Arc Jumpstart | [azurearcjumpstart.com](https://azurearcjumpstart.com/) |
| Flux CD docs | [fluxcd.io/docs/](https://fluxcd.io/docs/) |
| Linkerd service mesh | [linkerd.io](https://linkerd.io/) |
| SMI Traffic Split spec | [smi-spec.io](https://smi-spec.io/) |
| OPA Gatekeeper | [open-policy-agent.github.io/gatekeeper/](https://open-policy-agent.github.io/gatekeeper/) |

---

## Thank You!

Thank you for completing this hands-on lab! We hope it gave you a concrete understanding of how Azure Arc extends Azure management to any Kubernetes cluster — wherever it runs.

If you have feedback or questions, feel free to open an issue in this repository or reach out via the links above.

**Happy Arc-ing!** 🚀
