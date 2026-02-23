# Azure Arc-enabled Kubernetes — Workshop (1–1.5 hours)

> **Audience:** Cloud Engineers / DevOps  
> **Level:** Intermediate – Advanced  
> **Prerequisites:** Azure subscription (Owner/Contributor), Azure CLI + AZD CLI installed  
> **Repository:** This folder is a fully self-contained AZD project

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
| 0   | **Introductie & Architectuur**             | 5 min       | Slides/Whiteboard |
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
|     | **Totaal**                                 | **~95 min** |                   |

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

## Section 0: Introductie & Architectuur (5 min)

### Talking Notes

**Wat is Azure Arc?**

- Azure Arc breidt de Azure control plane uit naar **elke infrastructuur**: on-prem, edge, multi-cloud
- Het is **geen data plane migratie** — je workloads blijven waar ze zijn
- Azure Arc voor Kubernetes maakt het mogelijk om **elke CNCF-conforme K8s cluster** te beheren vanuit Azure

**Waarom Arc-enabled Kubernetes?**

- **Eén management plane** voor alle clusters (AKS, EKS, GKE, on-prem, edge)
- **Consistent beleid** — Azure Policy werkt identiek op AKS en Arc
- **Centraal overzicht** — alle clusters in Azure Resource Graph
- **GitOps native** — Flux v2 is ingebouwd, niet een add-on
- **Geen inbound firewall regels nodig** — agents maken outbound HTTPS verbindingen

**Wat gaan we vandaag doen?**

- Een K3s cluster opzetten in een VM (simuleert on-prem)
- Dat cluster verbinden met Azure Arc
- Alle enterprise features demonstreren: Policy, Defender, Monitoring, GitOps
- Alles geautomatiseerd met Infrastructure as Code (Bicep + AZD)

**Key message:** _"Arc brengt Azure naar je infrastructuur, niet je infrastructuur naar Azure."_

---

## Section 1: Deploy Infrastructure — AZD + Bicep (10 min)

### Talking Notes

**Wat deployen we?**

- Een Ubuntu VM die onze "on-premises server" simuleert
- Een VNet met NSG (SSH, HTTPS, K8s API open)
- Een Log Analytics Workspace (voor monitoring later)
- Alles via **Bicep** en **Azure Developer CLI (AZD)**

**Waarom AZD?**

- AZD is de developer-first CLI voor Azure
- Combineert infra provisioning (Bicep) met app deployment
- Eenvoudige `azd up` om alles te deployen
- Environment management (dev, staging, prod)
- Ingebouwde hooks voor pre/post provisioning

**Walk-through van de Bicep code:**

### Demo Steps

```bash
# 1. Show the project structure
tree .  # or: Get-ChildItem -Recurse (PowerShell)
```

**Bespreek de bestanden:**

| File                               | Purpose                                                      |
| ---------------------------------- | ------------------------------------------------------------ |
| `azure.yaml`                       | AZD project definitie — verwijst naar infra/main.bicep       |
| `infra/main.bicep`                 | Main orchestrator — subscription scope, creates RG + modules |
| `infra/modules/network.bicep`      | VNet, Subnet, NSG, Public IP                                 |
| `infra/modules/vm.bicep`           | Ubuntu 22.04 VM met password auth                            |
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

**Key message:** _"Met AZD + Bicep is je hele workshop-omgeving reproduceerbaar. Eén commando, alles staat klaar."_

---

## Section 2: SSH & Install K3s (10 min)

### Talking Notes

**Wat is K3s?**

- Lightweight Kubernetes distributie door **Rancher (SUSE)**
- Volledig CNCF-gecertificeerd — 100% compatibel met standard K8s
- Enkele binary van ~70MB (vs. ~700MB+ voor standard kubeadm)
- Ideaal voor **edge, IoT, development, resource-constrained** omgevingen
- Bevat alles: containerd, Flannel CNI, CoreDNS, Traefik, local-path storage

**Waarom K3s voor deze demo?**

- Snelle installatie (~30 seconden)
- Lage resource requirements (512MB RAM, 1 CPU)
- Perfect om on-prem / edge scenario's te simuleren
- Azure Arc werkt met **elke** CNCF K8s distributie

### Demo Steps

```bash
# 1. SSH into the VM
ssh azureuser@<VM_PUBLIC_IP>
# (password from azd deployment)

# 2. Install K3s (show the script first, then run)
cat scripts/sh/02-install-k3s.sh

# Run it:
curl -sfL https://get.k3s.io | sh -

# 3. Configure kubectl
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

# 4. Verify the cluster
kubectl get nodes          # Should show 1 node (Ready)
kubectl get pods -A        # System pods (coredns, traefik, etc.)
kubectl cluster-info       # Cluster endpoint info
k3s --version              # K3s version
```

**Wijs op:**

- K3s draait als systemd service: `systemctl status k3s`
- Alles in één proces: API server, scheduler, controller manager, kubelet
- SQLite ipv etcd voor single-node (etcd beschikbaar voor HA)
- Traefik ingress controller is standaard geïnstalleerd

**Key message:** _"In 30 seconden heb je een productieklaar Kubernetes cluster. Dit draait nu volledig standalone, los van Azure."_

---

## Section 3: Arc Onboarding (10 min)

### Talking Notes

**Wat gebeurt er tijdens onboarding?**

- De `az connectedk8s connect` command installeert Arc agents in het cluster
- Agents worden gedeployed in de `azure-arc` namespace
- De agents maken een **outbound HTTPS** verbinding naar Azure (geen inbound poorten nodig!)
- Azure creëert een `connectedClusters` resource in je resource group

**Arc Agent componenten:** | Agent | Functie | |-------|---------| | `clusterconnect-agent` | Reverse proxy voor cluster access vanuit Azure | | `guard-agent` | Azure RBAC enforcement | | `cluster-metadata-operator` | Cluster metadata sync | | `config-agent` | GitOps/extensions configuratie | | `controller-manager` | Lifecycle management van agents |

**Security model:**

- Agents initiëren alle verbindingen (outbound only)
- Communicatie via Azure Relay (of direct endpoints)
- Managed Identity per cluster
- Geen credentials opgeslagen in Azure

### Demo Steps

```bash
# Still on the VM via SSH

# 1. Install Azure CLI (on the VM)
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# 2. Login (device code flow since we're remote)
az login --use-device-code

# 3. Install the connectedk8s extension
az extension add --name connectedk8s --yes

# 4. Set variables
export RESOURCE_GROUP="rg-arcworkshop"
export CLUSTER_NAME="arc-k3s-cluster"
export LOCATION="westeurope"

# 5. Connect the cluster to Azure Arc
az connectedk8s connect \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION

# 6. Verify — show status from CLI
az connectedk8s show \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  -o table

# 7. Verify — show Arc pods on the cluster
kubectl get pods -n azure-arc
kubectl get deployments -n azure-arc

# 8. PORTAL: Show the Arc cluster resource
#    Navigate to: Resource Group > arc-k3s-cluster
#    Show: Overview, Properties, Kubernetes version, Node count
```

**Wijs op in de portal:**

- Connected cluster resource met status "Connected"
- Kubernetes versie en node count worden automatisch gesynchroniseerd
- De cluster is nu zichtbaar in Azure Resource Graph
- Tags, RBAC, en Activity Log werken net als bij native Azure resources

**Key message:** _"Met één commando is je on-prem cluster onderdeel van Azure. Geen VPN, geen inbound firewall rules, geen agent management."_

---

## Section 4: Deploy Container from Azure (10 min)

### Talking Notes

**Cluster Connect feature:**

- Toegang tot de K8s API **via Azure**, zonder directe netwerkverbinding
- Werkt via de `az connectedk8s proxy` command
- Ideaal voor secure access zonder VPN of ExpressRoute
- Gebruikt Azure RBAC voor autorisatie

**Wat demonstreren we?**

- Vanuit je lokale machine, via Azure, een container deployen op het Arc cluster
- Dit bewijst dat Azure de "single pane of glass" is

### Demo Steps

```bash
# Back on your LOCAL machine (not the VM)

# METHOD 1: Cluster Connect (via Azure proxy)
# Start the proxy in a terminal
az connectedk8s proxy \
  -n arc-k3s-cluster \
  -g rg-arcworkshop &

# Now use kubectl locally as if the cluster is local!
kubectl get nodes
kubectl get pods -A

# Deploy the demo app
kubectl apply -f k8s/demo-app.yaml

# Watch the deployment
kubectl get pods -n demo -w

# METHOD 2: Via SSH (simpler)
scp k8s/demo-app.yaml azureuser@<VM_IP>:~/
ssh azureuser@<VM_IP> "kubectl apply -f ~/demo-app.yaml"

# PORTAL: Show the workload in Azure Portal
#   Arc cluster > Kubernetes resources > Workloads
#   - See the nginx-demo deployment
#   - See pods, services, replica sets
#   - Show the YAML view
#   Arc cluster > Kubernetes resources > Services and ingresses
```

**Wijs op in de portal:**

- **Kubernetes resources** blade: volledig overzicht van workloads
- Je kunt ook **direct vanuit de portal** YAML editen en toepassen
- Namespace filtering, search, en live status
- Dit werkt identiek voor Arc EN AKS clusters

**Key message:** _"Azure geeft je volledige visibility en control over workloads, ongeacht waar het cluster draait."_

---

## Section 5: Governance & Compliance — Azure Policy (10 min)

### Talking Notes

**Azure Policy voor Kubernetes:**

- Dezelfde Azure Policy engine die je kent voor Azure resources
- Gebruikt **OPA Gatekeeper** onder de hood voor K8s enforcement
- Werkt identiek op AKS en Arc-connected clusters
- **Audit** mode (rapporteer) of **Deny** mode (blokkeer)

**Wat configureren we?**

1. **No privileged containers** — Voorkom containers met root-level access
2. **Require labels** — Enforce dat pods een `environment` label hebben
3. **Allowed registries** — Alleen images van trusted registries toestaan

**Waarom dit belangrijk is:**

- Consistente security baseline over ALLE clusters
- Compliance rapportage in één dashboard
- Automatische enforcement — geen handmatige reviews nodig
- Audit trail voor regelgeving (SOC2, ISO27001, etc.)

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
  --policy "95edb821-ddaf-4404-9ab7-b7b2c97b44e7" \
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

**Wijs op:**

- Het duurt ~15-30 minuten voor policies volledig geëvalueerd zijn
- Gatekeeper pods in de `gatekeeper-system` namespace
- Policy compliance dashboard in de portal
- Je kunt ook **initiative definitions** gebruiken voor groepen policies

**Key message:** _"Eén set policies, overal afgedwongen. Of het nu AKS in Azure is of K3s op een edge server — dezelfde regels, dezelfde compliance."_

---

## Section 6: Microsoft Defender for Containers (5 min)

### Talking Notes

**Wat biedt Defender voor Arc-connected clusters?**

- **Runtime threat detection** — verdachte processen, crypto mining, reverse shells
- **Vulnerability scanning** — CVE's in container images
- **Security recommendations** — best practices voor cluster hardening
- **Security alerts** — real-time notificaties bij threats

**Hoe werkt het?**

- Defender sensor (DaemonSet) draait op elke node
- Stuurt security data naar de Defender backend via Arc
- Gecombineerd met Log Analytics voor correlatie
- Dezelfde Defender ervaring als voor AKS

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

# 3. PORTAL DEMO:
#    - Defender for Cloud > Workload protections > Containers
#    - Security recommendations for the Arc cluster
#    - Security alerts (if any)
#    - Secure score impact
```

**Key message:** _"Enterprise-grade security voor elke K8s cluster, beheerd vanuit Defender for Cloud. Dezelfde bescherming als AKS, ongeacht de locatie."_

---

## Section 7: Monitoring & Observability (10 min)

### Talking Notes

**Container Insights via Azure Monitor:**

- Dezelfde monitoring ervaring als AKS
- CPU, memory, network metrics per node/pod/container
- Container logs centraal in Log Analytics
- Pre-built workbooks en dashboards
- KQL queries voor diepgaande analyse

**Hoe werkt het?**

- Azure Monitor agent (AMA) als extension op het Arc cluster
- Data wordt naar Log Analytics gestuurd
- Perf data, inventory, en logs — alles gecorreleerd

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

**Wijs op:**

- Multi-cluster monitoring: Arc EN AKS clusters naast elkaar
- Custom alerts op basis van KQL queries
- Workbooks zijn deelbaar en aanpasbaar
- Data retention configureerbaar (30-730 dagen)

**Key message:** _"Eén monitoring platform voor al je clusters. Dezelfde KQL queries, dezelfde dashboards, of het nu Arc of AKS is."_

---

## Section 8: GitOps with Flux (10 min)

### Talking Notes

**Wat is GitOps?**

- **Git als single source of truth** voor cluster configuratie
- Pull-based model: Flux in het cluster haalt wijzigingen op
- Automatische reconciliation: drift wordt automatisch gecorrigeerd
- Audit trail via Git history

**Flux v2 op Azure Arc:**

- CNCF graduated project, native geïntegreerd in Azure
- Ondersteunt Kustomize en Helm
- Beheerd via Azure (`az k8s-configuration flux`)
- Compliance status zichtbaar in Azure Portal
- Werkt identiek op AKS en Arc

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
  --url https://github.com/Azure/arc-k8s-demo \
  --branch main \
  --kustomization name=cluster-config path=./releases/prod prune=true

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

**Wijs op:**

- Flux draait in `flux-system` namespace
- Private Git repos worden ondersteund (SSH keys, tokens)
- Helm charts worden ook ondersteund
- Multi-tenancy: namespace-scoped vs cluster-scoped configs

**Key message:** _"GitOps via Azure Arc: centraal beheer, automatische deployment, full audit trail. Configuratie IS code."_

---

## Section 9: Inventory Management (5 min)

### Talking Notes

**Azure Resource Graph:**

- Instant queries over ALLE Azure resources (incl. Arc clusters)
- Cross-subscription, cross-tenant queries
- Sub-second response times, zelfs bij duizenden resources
- Perfect voor compliance reporting en dashboards

**Typische use cases:**

- Hoeveel clusters draaien op verouderde K8s versie?
- Welke clusters missen de monitoring extension?
- Compliance status overzicht per cluster
- Clusters die offline zijn (disconnected)

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

**Key message:** _"Resource Graph geeft je instant overzicht over je hele Kubernetes fleet. Arc + AKS, één query."_

---

## Section 10: Copilot for Azure (5 min)

### Talking Notes

**Microsoft Copilot in Azure:**

- Natural language interface voor Azure management
- Geïntegreerd in de Azure Portal
- Begrijpt context van je huidige resource

**Demo scenario's voor Arc:**

- _"Toon me alle Arc-connected clusters die niet compliant zijn"_
- _"Wat is de status van mijn K3s cluster?"_
- _"Hoeveel nodes heeft mijn Arc cluster?"_
- _"Maak een KQL query om container errors te vinden"_
- _"Welke policies zijn toegewezen aan mijn Arc cluster?"_
- _"Help me een GitOps configuratie aan te maken"_
- _"Wat zijn de security recommendations voor mijn cluster?"_

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

**Key message:** _"Copilot maakt Azure Arc nog toegankelijker. Natural language, contextbewust, en geïntegreerd in je workflow."_

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

### Kernboodschap

> **Azure Arc brengt de Azure management plane naar JE clusters — niet je clusters naar Azure.**  
> Dezelfde tools, dezelfde policies, dezelfde monitoring. Ongeacht waar je Kubernetes draait.

---

## Useful Links

- [Azure Arc-enabled Kubernetes docs](https://learn.microsoft.com/azure/azure-arc/kubernetes/)
- [K3s by Rancher](https://k3s.io/)
- [Azure Policy for Kubernetes](https://learn.microsoft.com/azure/governance/policy/concepts/policy-for-kubernetes)
- [GitOps with Flux v2](https://learn.microsoft.com/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2)
- [Container Insights for Arc](https://learn.microsoft.com/azure/azure-monitor/containers/container-insights-enable-arc-enabled-clusters)
- [Defender for Containers](https://learn.microsoft.com/azure/defender-for-cloud/defender-for-containers-introduction)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
