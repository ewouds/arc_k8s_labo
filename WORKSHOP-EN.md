# Azure Arc-enabled Kubernetes — Workshop (1–1.5 hours)

> **Audience:** Cloud Engineers / DevOps  
> **Level:** Intermediate – Advanced  
> **Prerequisites:** Azure subscription (Owner/Contributor), Azure CLI + AZD CLI installed  
> **Repository:** This folder is a fully self-contained AZD project

> [!WARNING] **Security Disclaimer — Lab Use Only**  
> This workshop is designed for **learning and demonstration purposes**. Several practices used in this lab do **not** follow security best practices for production environments. Examples include:
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

## Agenda & Timing

| #   | Section                                    | Duration    | Type              |
| --- | ------------------------------------------ | ----------- | ----------------- |
| 0   | **Introduction & Architecture**            | 5 min       | Slides/Whiteboard |
| 1   | **Deploy Infrastructure (AZD + Bicep)**    | 10 min      | Live demo         |
| 2   | **SSH & Install K3s (Rancher)**            | 10 min      | Live demo         |
| 3   | **Arc Onboarding**                         | 10 min      | Live demo         |
| 4   | **Deploy Container from Azure**            | 10 min      | Live demo         |
| 5   | **Governance & Compliance (Azure Policy)** | 10 min      | Live demo         |
| 6   | **Microsoft Defender for Containers**      | 5 min       | Demo + Portal     |
| 7   | **Monitoring & Observability**             | 10 min      | Demo + Portal     |
| 8   | **GitOps with Flux**                       | 10 min      | Live demo         |
| 9   | **Inventory Management**                   | 5 min       | Live demo         |
| 10  | **Copilot for Azure**                      | 5 min       | Portal demo       |
| —   | **Q&A & Cleanup**                          | 5 min       | Discussion        |
|     | **Total**                                  | **~95 min** |                   |

---

## Pre-workshop Preparation (do this the day before!)

```bash
# 1. Clone this repo
git clone <REPO_URL> && cd arc_k8s

# 2. Initialize AZD
azd init

# 3. Run prerequisites check
bash scripts/sh/00-prereqs.sh      # Linux/WSL/Git Bash
# .\scripts\ps1\00-prereqs.ps1    # PowerShell

# 4. Deploy infrastructure (takes ~5 min)
azd up
#   Environment name: arcworkshop
#   Location: westeurope
#   VM password: <choose a strong password>

# 5. Note the outputs (VM IP, SSH command)
azd env get-values
```

> **TIP:** Deploy the infrastructure BEFORE the workshop starts so you don't waste demo time waiting. You can always walk through the Bicep code without actually deploying.

---

## Section 0: Introduction & Architecture (5 min)

### Talking Notes

**What is Azure Arc?**

- Azure Arc extends the Azure control plane to **any infrastructure**: on-prem, edge, multi-cloud
- It is **not a data plane migration** — your workloads stay where they are
- Azure Arc for Kubernetes enables managing **any CNCF-compliant K8s cluster** from Azure

**Why Arc-enabled Kubernetes?**

- **One management plane** for all clusters (AKS, EKS, GKE, on-prem, edge)
- **Consistent policies** — Azure Policy works identically on AKS and Arc
- **Central overview** — all clusters in Azure Resource Graph
- **GitOps native** — Flux v2 is built-in, not an add-on
- **No inbound firewall rules required** — agents make outbound HTTPS connections

**What are we going to do today?**

- Set up a K3s cluster in a VM (simulates on-prem)
- Connect that cluster to Azure Arc
- Demonstrate all enterprise features: Policy, Defender, Monitoring, GitOps
- Everything automated with Infrastructure as Code (Bicep + AZD)

**Key message:** _"Arc brings Azure to your infrastructure, not your infrastructure to Azure."_

---

## Section 1: Deploy Infrastructure — AZD + Bicep (10 min)

### Talking Notes

**What are we deploying?**

- An Ubuntu VM that simulates our "on-premises server"
- A VNet with NSG (SSH, HTTPS, K8s API open)
- A Log Analytics Workspace (for monitoring later)
- Everything via **Bicep** and **Azure Developer CLI (AZD)**

**Why AZD?**

- AZD is the developer-first CLI for Azure
- Combines infra provisioning (Bicep) with app deployment
- Simple `azd up` to deploy everything
- Environment management (dev, staging, prod)
- Built-in hooks for pre/post provisioning

**Walk-through of the Bicep code:**

### Demo Steps

```bash
# 1. Show the project structure
tree .  # or: Get-ChildItem -Recurse (PowerShell)
```

**Discuss the files:**

| File                               | Purpose                                                      |
| ---------------------------------- | ------------------------------------------------------------ |
| `azure.yaml`                       | AZD project definition — points to infra/main.bicep          |
| `infra/main.bicep`                 | Main orchestrator — subscription scope, creates RG + modules |
| `infra/modules/network.bicep`      | VNet, Subnet, NSG, Public IP                                 |
| `infra/modules/vm.bicep`           | Ubuntu 22.04 VM with password auth                           |
| `infra/modules/loganalytics.bicep` | Log Analytics workspace                                      |

```bash
# 2. Walk through main.bicep
#    - Show targetScope = 'subscription'
#    - Show parameters (environmentName, location, vmAdminPassword)
#    - Show module references
#    - Show outputs (VM IP, SSH command)
cat infra/main.bicep

# 3. Walk through a module (e.g., network.bicep)
cat infra/modules/network.bicep
#    - Show NSG rules (SSH 22, HTTPS 443, K8s API 6443)
#    - Show Public IP with DNS label

# 4. Deploy (if not pre-deployed)
azd up
#    Enter environment name: arcworkshop
#    Select location: West Europe
#    Enter VM password: <strong-password>

# 5. Show the outputs
azd env get-values
#    VM_PUBLIC_IP=x.x.x.x
#    SSH_COMMAND=ssh azureuser@x.x.x.x
```

**Key message:** _"With AZD + Bicep your entire workshop environment is reproducible. One command, everything is ready."_

---

## Section 2: SSH & Install K3s (10 min)

### Talking Notes

**What is K3s?**

- Lightweight Kubernetes distribution by **Rancher (SUSE)**
- Fully CNCF-certified — 100% compatible with standard K8s
- Single binary of ~70MB (vs. ~700MB+ for standard kubeadm)
- Ideal for **edge, IoT, development, resource-constrained** environments
- Includes everything: containerd, Flannel CNI, CoreDNS, Traefik, local-path storage

**Why K3s for this demo?**

- Fast installation (~30 seconds)
- Low resource requirements (512MB RAM, 1 CPU)
- Perfect for simulating on-prem / edge scenarios
- Azure Arc works with **any** CNCF K8s distribution

### Demo Steps

```bash
# 1. SSH into the VM
ssh azureuser@<VM_PUBLIC_IP>
# (password from azd deployment)
```

> **The script `02-install-k3s.sh` automates all of the steps below.** You only need to run the script — the individual commands are shown here for explanation purposes so you can walk through what happens under the hood.

```bash
# 2. Run the installation script (this does everything automatically)
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

**Point out:**

- K3s runs as a systemd service: `systemctl status k3s`
- Everything in one process: API server, scheduler, controller manager, kubelet
- SQLite instead of etcd for single-node (etcd available for HA)
- Traefik ingress controller is installed by default

**Key message:** _"In 30 seconds you have a production-ready Kubernetes cluster. It now runs fully standalone, independent from Azure."_

---

## Section 3: Arc Onboarding (10 min)

### Talking Notes

**What happens during onboarding?**

- The `az connectedk8s connect` command installs Arc agents in the cluster
- Agents are deployed in the `azure-arc` namespace
- The agents make an **outbound HTTPS** connection to Azure (no inbound ports needed!)
- Azure creates a `connectedClusters` resource in your resource group

**Arc Agent components:**

| Agent                       | Function                                    |
| --------------------------- | ------------------------------------------- |
| `clusterconnect-agent`      | Reverse proxy for cluster access from Azure |
| `guard-agent`               | Azure RBAC enforcement                      |
| `cluster-metadata-operator` | Cluster metadata sync                       |
| `config-agent`              | GitOps/extensions configuration             |
| `controller-manager`        | Lifecycle management of agents              |

**Security model:**

- Agents initiate all connections (outbound only)
- Communication via Azure Relay (or direct endpoints)
- Managed Identity per cluster
- No credentials stored in Azure

### Demo Steps

```bash
# 1. SSH into the VM (if not already connected)
ssh azureuser@<VM_PUBLIC_IP>
```

> **The script `03-arc-onboard.sh` automates all the steps below.** You only need to run the script — the individual commands are shown here for clarification so you can explain what's happening under the hood.

```bash
# 2. Run the onboarding script (this does everything automatically)
bash 03-arc-onboard.sh
```

**What does the script do?**

1. **Install Azure CLI** — installs the Azure CLI on the VM via the official install script (`curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`)
2. **Log in to Azure** — starts a device code flow login (`az login --use-device-code`) since we're working remotely via SSH. We use an interactive login here because we're onboarding **a single cluster** manually in the demo.
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

**After the script — show in the portal:**

```bash
# PORTAL: Show the Arc cluster resource
#    Navigate to: Resource Group > arc-k3s-cluster
#    Show: Overview, Properties, Kubernetes version, Node count
```

**Point out in the portal:**

- Connected cluster resource with status "Connected"
- Kubernetes version and node count are automatically synchronized
- The cluster is now visible in Azure Resource Graph
- Tags, RBAC, and Activity Log work just like native Azure resources

**Key message:** _"With one command, your on-prem cluster is part of Azure. No VPN, no inbound firewall rules, no agent management."_

---

## Section 4: Deploy Container from Azure (10 min)

### Talking Notes

**Cluster Connect feature:**

- Access to the K8s API **via Azure**, without a direct network connection
- Works via the `az connectedk8s proxy` command
- Ideal for secure access without VPN or ExpressRoute
- Uses Azure RBAC for authorization

**What are we demonstrating?**

- From your local machine, via Azure, deploy a container to the Arc cluster
- **This is the core value of Arc:** you don't need SSH, VPN, or direct network access — Azure acts as a secure proxy to your cluster

### Demo Steps

```bash
# Back on your LOCAL machine (not the VM)

# 1. Start the Cluster Connect proxy
#    This opens a tunnel via Azure to your Arc cluster
az connectedk8s proxy \
  -n arc-k3s-cluster \
  -g rg-arcworkshop &

# 2. kubectl now works locally as if the cluster is right next to you!
#    Behind the scenes, all traffic flows through Azure Arc
kubectl get nodes
kubectl get pods -A

# 3. Deploy the demo app — directly from your laptop
kubectl apply -f k8s/demo-app.yaml

# 4. Watch the deployment
kubectl get pods -n demo -w
```

> **Why is this special?** Your laptop has no direct network connection to the VM or the cluster. All communication flows through Azure Arc as a reverse proxy. In a production environment, this means: no VPN needed, no ports to open, and access controlled via Azure RBAC.

```bash
# 5. PORTAL: Show the workload in Azure Portal
#   Arc cluster > Kubernetes resources > Workloads
#   - See the nginx-demo deployment
#   - See pods, services, replica sets
#   - Show the YAML view
#   Arc cluster > Kubernetes resources > Services and ingresses
```

> **Fallback:** if Cluster Connect doesn't work during the demo, you can also deploy the app via SSH:
>
> ```bash
> scp k8s/demo-app.yaml azureuser@<VM_IP>:~/
> ssh azureuser@<VM_IP> "kubectl apply -f ~/demo-app.yaml"
> ```

### Step 2: Deploy a second container via the Azure Portal

**What are we demonstrating?**

- You can also **deploy a workload directly from the Azure Portal** by pasting YAML
- No CLI needed — ideal for quick actions or when you don't have local tooling
- **End result:** two containers running on-prem on the Arc-connected cluster

**Demo Steps:**

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
        - name: httpd
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

5. Wait for the pod to be `Running` — verify in **Workloads** or via CLI:

```bash
kubectl get pods -n demo
# Expected: nginx-demo pods + hello-arc pod
```

> **Why show this?** It highlights that Azure Arc provides the same portal experience as AKS. Administrators can deploy, inspect, and manage workloads — all from one place, regardless of where the cluster runs.

**Point out in the portal:**

- **Kubernetes resources** blade: complete overview of workloads
- Now **two applications** (nginx-demo + hello-arc) are running on the on-prem cluster
- You can also **edit and apply YAML directly from the portal**
- Namespace filtering, search, and live status
- This works identically for Arc AND AKS clusters

**Key message:** _"Azure gives you full visibility and control over workloads, regardless of where the cluster runs — via CLI and via the portal."_

---

## Section 5: Governance & Compliance — Azure Policy (10 min)

### Talking Notes

**Azure Policy for Kubernetes:**

- The same Azure Policy engine you know for Azure resources
- Uses **OPA Gatekeeper** under the hood for K8s enforcement
- Works identically on AKS and Arc-connected clusters
- **Audit** mode (report) or **Deny** mode (block)

**What are we configuring?**

1. **No privileged containers** — Prevent containers with root-level access
2. **Require labels** — Enforce that pods have an `environment` label
3. **Allowed registries** — Only allow images from trusted registries

**Why this matters:**

- Consistent security baseline across ALL clusters
- Compliance reporting in one dashboard
- Automatic enforcement — no manual reviews needed
- Audit trail for regulations (SOC2, ISO27001, etc.)

### Demo Steps

```bash
# From your LOCAL machine

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

# 5. DEMO: Try to deploy a privileged pod (should be DENIED!)
# On the VM:
ssh azureuser@<VM_IP> "kubectl apply -f ~/privileged-pod.yaml"
# Expected output: Error from server (Forbidden): admission webhook denied the request

# 6. PORTAL: Show Policy Compliance
#    Arc cluster > Policies
#    Azure Policy > Compliance (filter by resource group)
```

> **⚠️ Important:** Policies need **15-30 minutes** to sync to the cluster via Gatekeeper.
> The privileged pod test (step 5) will only fail **after** Gatekeeper has synced the constraints.
>
> **How to check if policies are ready:**
> ```bash
> # Check if Gatekeeper constraints exist (empty = not yet synced)
> kubectl get constraints
> kubectl get constrainttemplates
>
> # Check Gatekeeper pods are running
> kubectl get pods -n gatekeeper-system
> ```
>
> If `kubectl get constraints` returns results, the policies are active and the privileged pod will be denied.
> While waiting, you can continue with the next sections and come back to test later.

**Point out:**

- It takes ~15-30 minutes for policies to be fully evaluated
- Gatekeeper pods in the `gatekeeper-system` namespace
- Policy compliance dashboard in the portal
- You can also use **initiative definitions** for groups of policies

**Key message:** _"One set of policies, enforced everywhere. Whether it's AKS in Azure or K3s on an edge server — same rules, same compliance."_

---

## Section 6: Microsoft Defender for Containers (5 min)

### Talking Notes

**What does Defender offer for Arc-connected clusters?**

- **Runtime threat detection** — suspicious processes, crypto mining, reverse shells
- **Vulnerability scanning** — CVEs in container images
- **Security recommendations** — best practices for cluster hardening
- **Security alerts** — real-time notifications for threats

**How does it work?**

- Defender sensor (DaemonSet) runs on every node
- Sends security data to the Defender backend via Arc
- Combined with Log Analytics for correlation
- Same Defender experience as for AKS

### Demo Steps

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

# 4. Disable governance policies (if Section 5 was completed)
#    The test alert image may be blocked by the allowed-registries policy
#    and the require-labels policy. Disable them temporarily:
.\scripts\ps1\05a-toggle-policies.ps1 disable   # PowerShell
# OR: bash scripts/sh/05a-toggle-policies.sh disable   # Bash

# 5. Trigger a test security alert
ssh azureuser@<VM_IP> "kubectl run defender-test \
  --image=mcr.microsoft.com/aks/security/test-alert \
  --restart=Never \
  --labels=environment=workshop"

# 6. PORTAL DEMO:
#    - Defender for Cloud > Workload protections > Containers
#    - Defender for Cloud > Security alerts (test alert ~30 min)
#    - Defender for Cloud > Recommendations (filter: connectedClusters)
#    - Arc cluster > Security blade
#    - Secure score impact

# 7. Cleanup test pod & re-enable policies
ssh azureuser@<VM_IP> "kubectl delete pod defender-test --ignore-not-found"
.\scripts\ps1\05a-toggle-policies.ps1 enable   # PowerShell
# OR: bash scripts/sh/05a-toggle-policies.sh enable   # Bash
```

> **Note:** The test alert takes approximately **30 minutes** to appear in the Security Alerts blade.
> For a live demo, trigger the test alert beforehand so it's already visible when you present this section.

**Key message:** _"Enterprise-grade security for any K8s cluster, managed from Defender for Cloud. Same protection as AKS, regardless of location."_

---

## Section 7: Monitoring & Observability (10 min)

### Talking Notes

**Container Insights via Azure Monitor:**

- Same monitoring experience as AKS
- CPU, memory, network metrics per node/pod/container
- Container logs centralized in Log Analytics
- Pre-built workbooks and dashboards
- KQL queries for in-depth analysis

**How does it work?**

- Azure Monitor agent (AMA) as extension on the Arc cluster
- Data is sent to Log Analytics
- Perf data, inventory, and logs — all correlated

### Demo Steps

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

# 3. PORTAL DEMO:
#    Arc cluster > Insights
#    - Cluster tab: node CPU/memory heatmap
#    - Nodes tab: per-node resource utilization
#    - Controllers tab: deployment health
#    - Containers tab: individual container metrics
#
#    Arc cluster > Logs
#    - Run KQL queries:

# Example KQL: Pod inventory
# KubePodInventory
# | where ClusterName == "arc-k3s-cluster"
# | summarize count() by PodStatus, Namespace
# | render piechart

# Example KQL: Container CPU
# Perf
# | where ObjectName == "K8SContainer"
# | where CounterName == "cpuUsageNanoCores"
# | summarize avg(CounterValue) by InstanceName, bin(TimeGenerated, 5m)
# | render timechart

#    Arc cluster > Workbooks
#    - Pre-built workbooks for K8s monitoring
#
#    Azure Monitor > Containers
#    - Multi-cluster view (Arc + AKS together!)
```

**Point out:**

- Multi-cluster monitoring: Arc AND AKS clusters side by side
- Custom alerts based on KQL queries
- Workbooks are shareable and customizable
- Data retention configurable (30-730 days)

**Key message:** _"One monitoring platform for all your clusters. Same KQL queries, same dashboards, whether it's Arc or AKS."_

---

## Section 8: GitOps with Flux (10 min)

### Talking Notes

**What is GitOps?**

- **Git as the single source of truth** for cluster configuration
- Pull-based model: Flux in the cluster pulls changes
- Automatic reconciliation: drift is automatically corrected
- Audit trail via Git history

**Flux v2 on Azure Arc:**

- CNCF graduated project, natively integrated into Azure
- Supports Kustomize and Helm
- Managed via Azure (`az k8s-configuration flux`)
- Compliance status visible in Azure Portal
- Works identically on AKS and Arc

**Workflow:**

```
Developer → Git Push → Flux detects → Flux applies → Cluster state updated
                                                           ↓
                                              Azure shows compliance ✅
```

### Demo Steps

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
  --branch main \
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

# 5. PORTAL: Show GitOps in the portal
#    Arc cluster > GitOps
#    - Configuration name, source repo
#    - Compliance state (Compliant / Non-compliant)
#    - Kustomization details
#    - Last sync time

# 6. DEMO: Show what happens when you change the repo
#    - Change replica count in Git
#    - Flux detects and applies (default: 10 min interval)
#    - Or force sync: az k8s-configuration flux update ...
```

**Point out:**

- Flux runs in the `flux-system` namespace
- Private Git repos are supported (SSH keys, tokens)
- Helm charts are also supported
- Multi-tenancy: namespace-scoped vs cluster-scoped configs

**Key message:** _"GitOps via Azure Arc: centralized management, automatic deployment, full audit trail. Configuration IS code."_

---

## Section 9: Inventory Management (5 min)

### Talking Notes

**Azure Resource Graph:**

- Instant queries across ALL Azure resources (incl. Arc clusters)
- Cross-subscription, cross-tenant queries
- Sub-second response times, even with thousands of resources
- Perfect for compliance reporting and dashboards

**Typical use cases:**

- How many clusters are running an outdated K8s version?
- Which clusters are missing the monitoring extension?
- Compliance status overview per cluster
- Clusters that are offline (disconnected)

### Demo Steps

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
az graph query -q "
  resources
  | where type in (
      'microsoft.kubernetes/connectedclusters',
      'microsoft.containerservice/managedclusters')
  | extend clusterType = iff(type contains 'connected', 'Arc', 'AKS')
  | project name, clusterType, location,
            k8sVersion=properties.kubernetesVersion
" -o table

# 3. PORTAL: Azure Resource Graph Explorer
#    - Run queries interactively
#    - Pin to Azure Dashboard
#    - Export to CSV

# 4. PORTAL: Arc > Kubernetes clusters
#    - Unified list of all Arc clusters
#    - Filter, sort, tag management
```

**Key message:** _"Resource Graph gives you instant visibility across your entire Kubernetes fleet. Arc + AKS, one query."_

---

## Section 10: Copilot for Azure (5 min)

### Talking Notes

**Microsoft Copilot in Azure:**

- Natural language interface for Azure management
- Integrated into the Azure Portal
- Understands the context of your current resource

**Demo scenarios for Arc:**

- _"Show me all Arc-connected clusters that are non-compliant"_
- _"What is the status of my K3s cluster?"_
- _"How many nodes does my Arc cluster have?"_
- _"Create a KQL query to find container errors"_
- _"Which policies are assigned to my Arc cluster?"_
- _"Help me create a GitOps configuration"_
- _"What are the security recommendations for my cluster?"_

### Demo Steps

```
PORTAL DEMO (live):

1. Open Azure Portal
2. Click the Copilot icon (top bar)
3. Navigate to the Arc cluster resource

4. Ask: "What is the connectivity status of this cluster?"
   → Copilot shows cluster status, K8s version, node count

5. Ask: "Show me the policies assigned to this cluster"
   → Copilot lists policy assignments and compliance

6. Ask: "Generate a KQL query to find all error logs from my containers"
   → Copilot generates a ContainerLogV2 query

7. Ask: "What security recommendations does Defender have for this cluster?"
   → Copilot shows Defender recommendations

8. Ask: "How do I set up GitOps for this cluster?"
   → Copilot walks through the steps
```

**Key message:** _"Copilot makes Azure Arc even more accessible. Natural language, context-aware, and integrated into your workflow."_

---

## Cleanup

```bash
# Option 1: AZD (recommended)
azd down --purge --force

# Option 2: Manual
bash scripts/sh/99-cleanup.sh      # or: .\scripts\ps1\99-cleanup.ps1

# Option 3: Just delete the resource group
az group delete --name rg-arcworkshop --yes --no-wait
```

---

## Summary & Key Takeaways

| Capability              | What We Showed                                                   |
| ----------------------- | ---------------------------------------------------------------- |
| **Onboarding**          | `az connectedk8s connect` — one command to connect any K8s       |
| **Workload Deployment** | Deploy containers via Azure Portal, CLI, or Cluster Connect      |
| **Governance**          | Azure Policy with OPA Gatekeeper — same policies everywhere      |
| **Security**            | Microsoft Defender — runtime protection + vulnerability scanning |
| **Monitoring**          | Container Insights — same dashboards as AKS                      |
| **GitOps**              | Flux v2 — Git as source of truth, managed from Azure             |
| **Inventory**           | Resource Graph — instant queries across your entire fleet        |
| **AI-Assisted**         | Copilot — natural language management                            |

### Core Message

> **Azure Arc brings the Azure management plane to YOUR clusters — not your clusters to Azure.**  
> Same tools, same policies, same monitoring. Regardless of where your Kubernetes runs.

---

## Useful Links

- [Azure Arc-enabled Kubernetes docs](https://learn.microsoft.com/azure/azure-arc/kubernetes/)
- [K3s by Rancher](https://k3s.io/)
- [Azure Policy for Kubernetes](https://learn.microsoft.com/azure/governance/policy/concepts/policy-for-kubernetes)
- [GitOps with Flux v2](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2)
- [Container Insights for Arc](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-enable-arc-enabled-clusters)
- [Defender for Containers](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
