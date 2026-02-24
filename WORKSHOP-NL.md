# Azure Arc-enabled Kubernetes — Workshop (1–1,5 uur)

> **Doelgroep:** Cloud Engineers / DevOps  
> **Niveau:** Intermediate – Advanced  
> **Vereisten:** Azure abonnement (Owner/Contributor), Azure CLI + AZD CLI geïnstalleerd  
> **Repository:** Deze map is een volledig zelfstandig AZD-project

> [!WARNING] **Beveiligingswaarschuwing — Alleen voor Labgebruik**  
> Deze workshop is ontworpen voor **leer- en demonstratiedoeleinden**. Verschillende praktijken die in dit labo worden gebruikt, volgen **niet** de beveiligingsbest practices voor productieomgevingen. Voorbeelden:
>
> - Directe SSH-toegang met wachtwoordauthenticatie (gebruik in productie SSH-sleutels, Azure Bastion of Just-in-Time VM-toegang)
> - Poorten (22, 443, 6443) rechtstreeks openzetten op het publieke internet via NSG-regels
> - Gebruik van `--use-device-code` login op een remote VM
> - Wachtwoord-gebaseerde VM-authenticatie in plaats van Managed Identity / SSH-sleutels
> - Brede Contributor/Owner-roltoewijzingen
>
> **Pas in productie altijd het principe van least privilege toe, gebruik private endpoints, schakel netwerksegmentatie in en volg de Azure-beveiligingsbasislijn.**
>
> Aanbevolen lectuur:
>
> - [Azure Security Best Practices](https://learn.microsoft.com/azure/security/fundamentals/best-practices-and-patterns)
> - [Azure Arc-enabled Kubernetes Security](https://learn.microsoft.com/azure/azure-arc/kubernetes/security-overview)
> - [AKS/K8s Beveiligingsbasislijn](https://learn.microsoft.com/security/benchmark/azure/baselines/azure-kubernetes-service-aks-security-baseline)
> - [Azure Bastion (veilige VM-toegang)](https://learn.microsoft.com/azure/bastion/bastion-overview)

---

## Architectuuroverzicht

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
│  │ Workspace        │          │         │ (Inventaris)     │       │
│  └──────────────────┘          │         └──────────────────┘       │
│                                │                                    │
└────────────────────────────────┼────────────────────────────────────┘
                                 │ Outbound HTTPS (443)
                                 │ (agent-geïnitieerd, geen inbound nodig)
                                 │
┌────────────────────────────────┴─────────────────────────────────────┐
│                   "On-Premises" (Azure VM)                           │
│                                                                      │
│   ┌──────────────────────────────────────────────────────────────┐   │
│   │                    K3s Cluster (Rancher)                     │   │
│   │                                                              │   │
│   │   ┌──────────┐  ┌──────────┐  ┌──────────┐                   │   │
│   │   │ Arc      │  │ Flux     │  │ Jouw     │                   │   │
│   │   │ Agents   │  │ Agent    │  │ Workloads│                   │   │
│   │   └──────────┘  └──────────┘  └──────────┘                   │   │
│   │                                                              │   │
│   └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## Agenda & Timing

| #   | Sectie                                     | Duur        | Type              |
| --- | ------------------------------------------ | ----------- | ----------------- |
| 0   | **Introductie & Architectuur**             | 5 min       | Slides/Whiteboard |
| 1   | **Infrastructuur Deployen (AZD + Bicep)**  | 10 min      | Live demo         |
| 2   | **SSH & K3s Installeren (Rancher)**        | 10 min      | Live demo         |
| 3   | **Arc Onboarding**                         | 10 min      | Live demo         |
| 4   | **Container Deployen vanuit Azure**        | 10 min      | Live demo         |
| 5   | **Governance & Compliance (Azure Policy)** | 10 min      | Live demo         |
| 6   | **Microsoft Defender for Containers**      | 5 min       | Demo + Portal     |
| 7   | **Monitoring & Observability**             | 10 min      | Demo + Portal     |
| 8   | **GitOps met Flux**                        | 10 min      | Live demo         |
| 9   | **Inventarisbeheer**                       | 5 min       | Live demo         |
| 10  | **Copilot voor Azure**                     | 5 min       | Portal demo       |
| —   | **Q&A & Opruimen**                         | 5 min       | Discussie         |
|     | **Totaal**                                 | **~95 min** |                   |

---

## Voorbereiding voor de Workshop (doe dit de dag ervoor!)

```bash
# 1. Clone deze repo
git clone <REPO_URL> && cd arc_k8s

# 2. Initialiseer AZD
azd init

# 3. Voer prerequisite-controle uit
bash scripts/sh/00-prereqs.sh      # Linux/WSL/Git Bash
# .\scripts\ps1\00-prereqs.ps1    # PowerShell

# 4. Deploy infrastructuur (duurt ~5 min)
azd up
#   Omgevingsnaam: arcworkshop
#   Locatie: westeurope
#   VM wachtwoord: <kies een sterk wachtwoord>

# 5. Noteer de outputs (VM IP, SSH commando)
azd env get-values
```

> **TIP:** Deploy de infrastructuur VOOR de workshop begint zodat je geen demo-tijd verspilt met wachten. Je kunt altijd de Bicep-code doorlopen zonder daadwerkelijk te deployen.

---

## Sectie 0: Introductie & Architectuur (5 min)

### Spreeknotities

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

**Kernboodschap:** _"Arc brengt Azure naar je infrastructuur, niet je infrastructuur naar Azure."_

---

## Sectie 1: Infrastructuur Deployen — AZD + Bicep (10 min)

### Spreeknotities

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

**Doorloop van de Bicep-code:**

### Demo Stappen

```bash
# 1. Toon de projectstructuur
tree .  # of: Get-ChildItem -Recurse (PowerShell)
```

**Bespreek de bestanden:**

| Bestand                            | Doel                                                            |
| ---------------------------------- | --------------------------------------------------------------- |
| `azure.yaml`                       | AZD projectdefinitie — verwijst naar infra/main.bicep           |
| `infra/main.bicep`                 | Hoofd-orchestrator — subscription scope, maakt RG + modules aan |
| `infra/modules/network.bicep`      | VNet, Subnet, NSG, Publiek IP                                   |
| `infra/modules/vm.bicep`           | Ubuntu 22.04 VM met wachtwoordauthenticatie                     |
| `infra/modules/loganalytics.bicep` | Log Analytics werkruimte                                        |

```bash
# 2. Loop door main.bicep
#    - Toon targetScope = 'subscription'
#    - Toon parameters (environmentName, location, vmAdminPassword)
#    - Toon module-referenties
#    - Toon outputs (VM IP, SSH commando)
cat infra/main.bicep

# 3. Loop door een module (bijv. network.bicep)
cat infra/modules/network.bicep
#    - Toon NSG-regels (SSH 22, HTTPS 443, K8s API 6443)
#    - Toon Publiek IP met DNS-label

# 4. Deploy (als niet al vooraf gedeployed)
azd up
#    Voer omgevingsnaam in: arcworkshop
#    Selecteer locatie: West Europe
#    Voer VM wachtwoord in: <sterk-wachtwoord>

# 5. Toon de outputs
azd env get-values
#    VM_PUBLIC_IP=x.x.x.x
#    SSH_COMMAND=ssh azureuser@x.x.x.x
```

**Kernboodschap:** _"Met AZD + Bicep is je hele workshop-omgeving reproduceerbaar. Eén commando, alles staat klaar."_

---

## Sectie 2: SSH & K3s Installeren (10 min)

### Spreeknotities

**Wat is K3s?**

- Lichtgewicht Kubernetes-distributie door **Rancher (SUSE)**
- Volledig CNCF-gecertificeerd — 100% compatibel met standaard K8s
- Enkele binary van ~70MB (vs. ~700MB+ voor standaard kubeadm)
- Ideaal voor **edge, IoT, development, resource-beperkte** omgevingen
- Bevat alles: containerd, Flannel CNI, CoreDNS, Traefik, local-path storage

**Waarom K3s voor deze demo?**

- Snelle installatie (~30 seconden)
- Lage resource requirements (512MB RAM, 1 CPU)
- Perfect om on-prem / edge scenario's te simuleren
- Azure Arc werkt met **elke** CNCF K8s-distributie

### Demo Stappen

```bash
# 1. SSH naar de VM
ssh azureuser@<VM_PUBLIC_IP>
# (wachtwoord van azd deployment)
```

> **Het script `02-install-k3s.sh` automatiseert alle onderstaande stappen.** Je hoeft enkel het script uit te voeren — de individuele commando's worden hier ter verduidelijking getoond zodat je kunt uitleggen wat er onder de motorkap gebeurt.

```bash
# 2. Voer het installatiescript uit (dit doet alles automatisch)
bash 02-install-k3s.sh
```

**Wat doet het script?**

1. **Systeem bijwerken** — `apt-get update && upgrade` voor de laatste security patches
2. **K3s installeren** — downloadt en installeert K3s via het officiële instalscript (`curl -sfL https://get.k3s.io | sh -`). Dit omvat: containerd, Flannel CNI, CoreDNS, Traefik en local-path storage
3. **kubectl configureren** — kopieert de K3s kubeconfig naar `~/.kube/config` zodat `kubectl` direct werkt voor de huidige gebruiker
4. **Installatie verifiëren** — voert verificatiecommando's uit:

```bash
# Deze commando's worden automatisch door het script uitgevoerd:
kubectl get nodes          # Moet 1 node tonen (Ready)
kubectl get pods -A        # Systeem pods (coredns, traefik, etc.)
kubectl cluster-info       # Cluster endpoint info
k3s --version              # K3s versie
```

**Wijs op:**

- K3s draait als systemd service: `systemctl status k3s`
- Alles in één proces: API server, scheduler, controller manager, kubelet
- SQLite in plaats van etcd voor single-node (etcd beschikbaar voor HA)
- Traefik ingress controller is standaard geïnstalleerd

**Kernboodschap:** _"In 30 seconden heb je een productieklaar Kubernetes cluster. Dit draait nu volledig standalone, los van Azure."_

---

## Sectie 3: Arc Onboarding (10 min)

### Spreeknotities

**Wat gebeurt er tijdens onboarding?**

- Het `az connectedk8s connect` commando installeert Arc-agents in het cluster
- Agents worden gedeployed in de `azure-arc` namespace
- De agents maken een **outbound HTTPS** verbinding naar Azure (geen inbound poorten nodig!)
- Azure creëert een `connectedClusters` resource in je resource group

**Arc Agent-componenten:**

| Agent                       | Functie                                         |
| --------------------------- | ----------------------------------------------- |
| `clusterconnect-agent`      | Reverse proxy voor cluster-toegang vanuit Azure |
| `guard-agent`               | Azure RBAC-afdwinging                           |
| `cluster-metadata-operator` | Cluster metadata-synchronisatie                 |
| `config-agent`              | GitOps/extensions-configuratie                  |
| `controller-manager`        | Lifecycle management van agents                 |

**Beveiligingsmodel:**

- Agents initiëren alle verbindingen (alleen outbound)
- Communicatie via Azure Relay (of directe endpoints)
- Managed Identity per cluster
- Geen credentials opgeslagen in Azure

### Demo Stappen

```bash
# 1. SSH naar de VM (indien nog niet verbonden)
ssh azureuser@<VM_PUBLIC_IP>
```

> **Het script `03-arc-onboard.sh` automatiseert alle onderstaande stappen.** Je hoeft enkel het script uit te voeren — de individuele commando's worden hier ter verduidelijking getoond zodat je kunt uitleggen wat er onder de motorkap gebeurt.

```bash
# 2. Voer het onboarding-script uit (dit doet alles automatisch)
bash 03-arc-onboard.sh
```

**Wat doet het script?**

1. **Azure CLI installeren** — installeert de Azure CLI op de VM via het officiële installatiescript (`curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`)
2. **Inloggen op Azure** — start een device code flow login (`az login --use-device-code`) omdat we remote werken via SSH. We gebruiken hier een interactieve login omdat we in de demo **één enkel cluster** handmatig onboarden.
   > **At scale:** voor het onboarden van tientallen of honderden clusters gebruik je een **Service Principal** (`az login --service-principal`) of **Managed Identity**, gecombineerd met automatisering via Azure CLI scripts, Ansible, of CI/CD pipelines. Zie: [Arc K8s onboarding met Service Principal](https://learn.microsoft.com/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli#connect-using-a-service-principal) · [At-scale onboarding](https://learn.microsoft.com/azure/azure-arc/kubernetes/quickstart-connect-cluster?tabs=azure-cli#connect-a-large-number-of-clusters)
3. **connectedk8s-extensie installeren** — voegt de Arc K8s CLI-extensie toe (`az extension add --name connectedk8s`)
4. **Variabelen instellen** — stelt resource group, cluster naam en locatie in
5. **Cluster verbinden met Azure Arc** — voert het daadwerkelijke onboarding-commando uit:

```bash
# Dit commando wordt automatisch door het script uitgevoerd:
az connectedk8s connect \
  --name $CLUSTER_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION
```

6. **Verificatie** — controleert of de onboarding geslaagd is:

```bash
# Deze commando's worden automatisch door het script uitgevoerd:
az connectedk8s show --name $CLUSTER_NAME --resource-group $RESOURCE_GROUP -o table
kubectl get pods -n azure-arc
kubectl get deployments -n azure-arc
```

**Na het script — toon in de portal:**

```bash
# PORTAL: Toon de Arc cluster resource
#    Navigeer naar: Resource Group > arc-k3s-cluster
#    Toon: Overzicht, Eigenschappen, Kubernetes-versie, Aantal nodes
```

**Wijs op in de portal:**

- Connected cluster resource met status "Connected"
- Kubernetes-versie en aantal nodes worden automatisch gesynchroniseerd
- Het cluster is nu zichtbaar in Azure Resource Graph
- Tags, RBAC en Activity Log werken net als bij native Azure resources

**Kernboodschap:** _"Met één commando is je on-prem cluster onderdeel van Azure. Geen VPN, geen inbound firewall rules, geen agent management."_

---

## Sectie 4: Container Deployen vanuit Azure (10 min)

### Spreeknotities

**Cluster Connect-functie:**

- Toegang tot de K8s API **via Azure**, zonder directe netwerkverbinding
- Werkt via het `az connectedk8s proxy` commando
- Ideaal voor beveiligde toegang zonder VPN of ExpressRoute
- Gebruikt Azure RBAC voor autorisatie

**Wat demonstreren we?**

- Vanuit je lokale machine, via Azure, een container deployen op het Arc cluster
- **Dit is de kernwaarde van Arc:** je hebt geen SSH, VPN of directe netwerktoegang nodig — Azure fungeert als secure proxy naar je cluster

### Demo Stappen

```bash
# Terug op je LOKALE machine (niet de VM)

# 1. Start de Cluster Connect proxy
#    Dit opent een tunnel via Azure naar je Arc-cluster
az connectedk8s proxy \
  -n arc-k3s-cluster \
  -g rg-arcworkshop &

# 2. kubectl werkt nu lokaal alsof het cluster naast je draait!
#    Achter de schermen loopt al het verkeer via Azure Arc
kubectl get nodes
kubectl get pods -A

# 3. Deploy de demo-app — rechtstreeks vanaf je laptop
kubectl apply -f k8s/demo-app.yaml

# 4. Volg de deployment
kubectl get pods -n demo -w
```

> **Waarom is dit bijzonder?** Je laptop heeft geen directe netwerkverbinding met de VM of het cluster. Alle communicatie loopt via Azure Arc als reverse proxy. In een productieomgeving betekent dit: geen VPN nodig, geen poorten openzetten, en toegang gecontroleerd via Azure RBAC.

```bash
# 5. PORTAL: Toon de workload in Azure Portal
#   Arc cluster > Kubernetes-resources > Workloads
#   - Zie de nginx-demo deployment
#   - Zie pods, services, replica sets
#   - Toon de YAML-weergave
#   Arc cluster > Kubernetes-resources > Services en ingresses
```

> **Fallback:** werkt Cluster Connect niet tijdens de demo? Dan kun je de app ook via SSH deployen:
>
> ```bash
> scp k8s/demo-app.yaml azureuser@<VM_IP>:~/
> ssh azureuser@<VM_IP> "kubectl apply -f ~/demo-app.yaml"
> ```

### Stap 2: Tweede container deployen via de Azure Portal

**Wat demonstreren we?**

- Je kunt ook **rechtstreeks vanuit de Azure Portal** een workload deployen door YAML te plakken
- Geen CLI nodig — ideaal voor snelle acties of als je geen lokale tooling hebt
- **Eindresultaat:** twee containers draaien on-prem op het Arc-connected cluster

**Demo Stappen:**

1. Ga naar de **Azure Portal** → je Arc cluster (`arc-k3s-cluster`)
2. Navigeer naar **Kubernetes-resources** → **Workloads**
3. Klik bovenaan op **+ Maken** → **Toepassen met YAML**
4. Plak de onderstaande YAML en klik op **Toevoegen**:

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

5. Wacht tot de pod `Running` is — verifieer in **Workloads** of via CLI:

```bash
kubectl get pods -n demo
# Verwacht: nginx-demo pods + hello-arc pod
```

> **Waarom dit tonen?** Het benadrukt dat Azure Arc dezelfde portal-ervaring biedt als AKS. Beheerders kunnen workloads deployen, inspecteren en beheren — allemaal vanuit één plek, ongeacht waar het cluster draait.

**Wijs op in de portal:**

- **Kubernetes-resources** blade: volledig overzicht van workloads
- Nu draaien er **twee applicaties** (nginx-demo + hello-arc) op het on-prem cluster
- Je kunt ook **direct vanuit de portal** YAML bewerken en toepassen
- Namespace-filtering, zoeken en live status
- Dit werkt identiek voor Arc EN AKS clusters

**Kernboodschap:** _"Azure geeft je volledige visibility en control over workloads, ongeacht waar het cluster draait — via CLI én via de portal."_

---

## Sectie 5: Governance & Compliance — Azure Policy (10 min)

### Spreeknotities

**Azure Policy voor Kubernetes:**

- Dezelfde Azure Policy engine die je kent voor Azure resources
- Gebruikt **OPA Gatekeeper** onder de motorkap voor K8s-afdwinging
- Werkt identiek op AKS en Arc-connected clusters
- **Audit** modus (rapporteer) of **Deny** modus (blokkeer)

**Wat configureren we?**

1. **Geen geprivilegieerde containers** — Voorkom containers met root-level access
2. **Labels verplichten** — Verplicht dat pods een `environment` label hebben
3. **Toegestane registries** — Alleen images van vertrouwde registries toestaan

**Waarom dit belangrijk is:**

- Consistente beveiligingsbasislijn over ALLE clusters
- Compliance-rapportage in één dashboard
- Automatische afdwinging — geen handmatige reviews nodig
- Audit trail voor regelgeving (SOC2, ISO27001, etc.)

### Demo Stappen

```bash
# Vanaf je LOKALE machine

# 1. Installeer de Azure Policy-extensie op het Arc cluster
az k8s-extension create \
  --name azurepolicy \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  --extension-type Microsoft.PolicyInsights

# 2. Wacht tot de extensie gereed is
az k8s-extension show \
  --name azurepolicy \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  -o table

# 3. Haal het cluster resource-ID op
CLUSTER_ID=$(az connectedk8s show \
  -n arc-k3s-cluster \
  -g rg-arcworkshop \
  --query id -o tsv)

# 4. Wijs beleid toe: Geen geprivilegieerde containers
az policy assignment create \
  --name "no-privileged-containers" \
  --display-name "[Arc Workshop] Geen geprivilegieerde containers" \
  --policy "95edb821-ddaf-4404-9ab7-b7b2c97b44e7" \
  --scope "$CLUSTER_ID" \
  --params '{"effect": {"value": "Deny"}}'

# 5. DEMO: Probeer een geprivilegieerde pod te deployen (moet GEWEIGERD worden!)
# Op de VM:
ssh azureuser@<VM_IP> "kubectl apply -f ~/privileged-pod.yaml"
# Verwachte output: Error from server (Forbidden): admission webhook denied the request

# 6. PORTAL: Toon Beleidsnaleving
#    Arc cluster > Beleid
#    Azure Policy > Naleving (filter op resource group)
```

**Wijs op:**

- Het duurt ~15-30 minuten voor beleid volledig geëvalueerd is
- Gatekeeper-pods in de `gatekeeper-system` namespace
- Beleidsnalevingsdashboard in de portal
- Je kunt ook **initiatiefdefinities** gebruiken voor groepen beleidsregels

**Kernboodschap:** _"Eén set beleidsregels, overal afgedwongen. Of het nu AKS in Azure is of K3s op een edge server — dezelfde regels, dezelfde compliance."_

---

## Sectie 6: Microsoft Defender for Containers (5 min)

### Spreeknotities

**Wat biedt Defender voor Arc-connected clusters?**

- **Runtime dreigingsdetectie** — verdachte processen, crypto mining, reverse shells
- **Kwetsbaarheidsscanning** — CVE's in container images
- **Beveiligingsaanbevelingen** — best practices voor cluster hardening
- **Beveiligingswaarschuwingen** — real-time notificaties bij dreigingen

**Hoe werkt het?**

- Defender-sensor (DaemonSet) draait op elke node
- Stuurt beveiligingsdata naar de Defender-backend via Arc
- Gecombineerd met Log Analytics voor correlatie
- Dezelfde Defender-ervaring als voor AKS

### Demo Stappen

```bash
# 1. Schakel het Defender for Containers-abonnement in
az security pricing create --name Containers --tier Standard

# 2. Installeer de Defender-extensie
az k8s-extension create \
  --name microsoft.azuredefender.kubernetes \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  --extension-type microsoft.azuredefender.kubernetes \
  --configuration-settings "logAnalyticsWorkspaceResourceID=<WORKSPACE_ID>"

# 3. PORTAL DEMO:
#    - Defender for Cloud > Workload-bescherming > Containers
#    - Beveiligingsaanbevelingen voor het Arc cluster
#    - Beveiligingswaarschuwingen (indien aanwezig)
#    - Impact op Secure Score
```

**Kernboodschap:** _"Enterprise-grade beveiliging voor elk K8s cluster, beheerd vanuit Defender for Cloud. Dezelfde bescherming als AKS, ongeacht de locatie."_

---

## Sectie 7: Monitoring & Observability (10 min)

### Spreeknotities

**Container Insights via Azure Monitor:**

- Dezelfde monitoring-ervaring als AKS
- CPU, geheugen, netwerkmetrics per node/pod/container
- Container logs centraal in Log Analytics
- Kant-en-klare workbooks en dashboards
- KQL-queries voor diepgaande analyse

**Hoe werkt het?**

- Azure Monitor agent (AMA) als extensie op het Arc cluster
- Data wordt naar Log Analytics gestuurd
- Prestatiedata, inventaris en logs — alles gecorreleerd

### Demo Stappen

```bash
# 1. Installeer de Container Insights-extensie
az k8s-extension create \
  --name azuremonitor-containers \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  --extension-type Microsoft.AzureMonitor.Containers \
  --configuration-settings "logAnalyticsWorkspaceResourceID=<WORKSPACE_ID>"

# 2. Wacht ~5-10 minuten tot data begint te stromen

# 3. PORTAL DEMO:
#    Arc cluster > Inzichten
#    - Cluster tabblad: node CPU/geheugen heatmap
#    - Nodes tabblad: per-node resource-gebruik
#    - Controllers tabblad: deployment-gezondheid
#    - Containers tabblad: individuele container-metrics
#
#    Arc cluster > Logboeken
#    - Voer KQL-queries uit:

# Voorbeeld KQL: Pod-inventaris
# KubePodInventory
# | where ClusterName == "arc-k3s-cluster"
# | summarize count() by PodStatus, Namespace
# | render piechart

# Voorbeeld KQL: Container CPU
# Perf
# | where ObjectName == "K8SContainer"
# | where CounterName == "cpuUsageNanoCores"
# | summarize avg(CounterValue) by InstanceName, bin(TimeGenerated, 5m)
# | render timechart

#    Arc cluster > Werkmappen
#    - Kant-en-klare werkmappen voor K8s monitoring
#
#    Azure Monitor > Containers
#    - Multi-cluster weergave (Arc + AKS samengevoegd!)
```

**Wijs op:**

- Multi-cluster monitoring: Arc EN AKS clusters naast elkaar
- Aangepaste waarschuwingen op basis van KQL-queries
- Werkmappen zijn deelbaar en aanpasbaar
- Dataretentie configureerbaar (30-730 dagen)

**Kernboodschap:** _"Eén monitoringplatform voor al je clusters. Dezelfde KQL-queries, dezelfde dashboards, of het nu Arc of AKS is."_

---

## Sectie 8: GitOps met Flux (10 min)

### Spreeknotities

**Wat is GitOps?**

- **Git als enige bron van waarheid** voor clusterconfiguratie
- Pull-based model: Flux in het cluster haalt wijzigingen op
- Automatische reconciliatie: drift wordt automatisch gecorrigeerd
- Audit trail via Git-geschiedenis

**Flux v2 op Azure Arc:**

- CNCF graduated project, native geïntegreerd in Azure
- Ondersteunt Kustomize en Helm
- Beheerd via Azure (`az k8s-configuration flux`)
- Nalevingsstatus zichtbaar in Azure Portal
- Werkt identiek op AKS en Arc

**Workflow:**

```
Developer → Git Push → Flux detecteert → Flux past toe → Clusterstatus bijgewerkt
                                                               ↓
                                                  Azure toont naleving ✅
```

### Demo Stappen

```bash
# 1. Installeer de Flux-extensie
az k8s-extension create \
  --name flux \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  --extension-type microsoft.flux

# 2. Maak een GitOps-configuratie aan
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

# 3. Controleer synchronisatiestatus
az k8s-configuration flux show \
  --name demo-gitops \
  --cluster-name arc-k3s-cluster \
  --resource-group rg-arcworkshop \
  --cluster-type connectedClusters \
  -o table

# 4. Verifieer de deployments op de VM
ssh azureuser@<VM_IP> "kubectl get all --all-namespaces | grep -i gitops"

# 5. PORTAL: Toon GitOps in de portal
#    Arc cluster > GitOps
#    - Configuratienaam, bron-repo
#    - Nalevingsstatus (Compliant / Non-compliant)
#    - Kustomizatie-details
#    - Laatste synchronisatietijd

# 6. DEMO: Laat zien wat er gebeurt als je de repo wijzigt
#    - Wijzig replica count in Git
#    - Flux detecteert en past toe (standaard: 10 min interval)
#    - Of forceer sync: az k8s-configuration flux update ...
```

**Wijs op:**

- Flux draait in de `flux-system` namespace
- Private Git-repo's worden ondersteund (SSH keys, tokens)
- Helm charts worden ook ondersteund
- Multi-tenancy: namespace-scoped vs cluster-scoped configuraties

**Kernboodschap:** _"GitOps via Azure Arc: centraal beheer, automatische deployment, volledige audit trail. Configuratie IS code."_

---

## Sectie 9: Inventarisbeheer (5 min)

### Spreeknotities

**Azure Resource Graph:**

- Directe queries over ALLE Azure resources (incl. Arc clusters)
- Cross-subscription, cross-tenant queries
- Reactietijden onder de seconde, zelfs bij duizenden resources
- Perfect voor compliance-rapportage en dashboards

**Typische use cases:**

- Hoeveel clusters draaien op een verouderde K8s-versie?
- Welke clusters missen de monitoring-extensie?
- Nalevingsstatusoverzicht per cluster
- Clusters die offline zijn (disconnected)

### Demo Stappen

```bash
# 1. Query alle Arc-connected clusters
az graph query -q "
  resources
  | where type =~ 'microsoft.kubernetes/connectedclusters'
  | project name, resourceGroup, location,
            k8sVersion=properties.kubernetesVersion,
            status=properties.connectivityStatus
"

# 2. Vergelijk Arc + AKS clusters naast elkaar
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
#    - Voer queries interactief uit
#    - Pin aan Azure Dashboard
#    - Exporteer naar CSV

# 4. PORTAL: Arc > Kubernetes-clusters
#    - Samengevoegde lijst van alle Arc clusters
#    - Filteren, sorteren, tagbeheer
```

**Kernboodschap:** _"Resource Graph geeft je direct overzicht over je hele Kubernetes-vloot. Arc + AKS, één query."_

---

## Sectie 10: Copilot voor Azure (5 min)

### Spreeknotities

**Microsoft Copilot in Azure:**

- Natuurlijke taalinterface voor Azure-beheer
- Geïntegreerd in de Azure Portal
- Begrijpt de context van je huidige resource

**Demo-scenario's voor Arc:**

- _"Toon me alle Arc-connected clusters die niet compliant zijn"_
- _"Wat is de status van mijn K3s cluster?"_
- _"Hoeveel nodes heeft mijn Arc cluster?"_
- _"Maak een KQL-query om container errors te vinden"_
- _"Welke beleidsregels zijn toegewezen aan mijn Arc cluster?"_
- _"Help me een GitOps-configuratie aan te maken"_
- _"Wat zijn de beveiligingsaanbevelingen voor mijn cluster?"_

### Demo Stappen

```
PORTAL DEMO (live):

1. Open Azure Portal
2. Klik op het Copilot-icoon (bovenste balk)
3. Navigeer naar de Arc cluster resource

4. Vraag: "Wat is de verbindingsstatus van dit cluster?"
   → Copilot toont clusterstatus, K8s-versie, aantal nodes

5. Vraag: "Toon me de beleidsregels die aan dit cluster zijn toegewezen"
   → Copilot toont beleidstoewijzingen en naleving

6. Vraag: "Genereer een KQL-query om alle foutlogs van mijn containers te vinden"
   → Copilot genereert een ContainerLogV2-query

7. Vraag: "Welke beveiligingsaanbevelingen heeft Defender voor dit cluster?"
   → Copilot toont Defender-aanbevelingen

8. Vraag: "Hoe stel ik GitOps in voor dit cluster?"
   → Copilot doorloopt de stappen
```

**Kernboodschap:** _"Copilot maakt Azure Arc nog toegankelijker. Natuurlijke taal, contextbewust, en geïntegreerd in je workflow."_

---

## Opruimen

```bash
# Optie 1: AZD (aanbevolen)
azd down --purge --force

# Optie 2: Handmatig
bash scripts/sh/99-cleanup.sh      # of: .\scripts\ps1\99-cleanup.ps1

# Optie 3: Verwijder gewoon de resource group
az group delete --name rg-arcworkshop --yes --no-wait
```

---

## Samenvatting & Belangrijkste Conclusies

| Mogelijkheid            | Wat We Hebben Laten Zien                                          |
| ----------------------- | ----------------------------------------------------------------- |
| **Onboarding**          | `az connectedk8s connect` — één commando om elke K8s te verbinden |
| **Workload Deployment** | Containers deployen via Azure Portal, CLI of Cluster Connect      |
| **Governance**          | Azure Policy met OPA Gatekeeper — overal dezelfde beleidsregels   |
| **Beveiliging**         | Microsoft Defender — runtime-bescherming + kwetsbaarheidsscanning |
| **Monitoring**          | Container Insights — dezelfde dashboards als AKS                  |
| **GitOps**              | Flux v2 — Git als bron van waarheid, beheerd vanuit Azure         |
| **Inventaris**          | Resource Graph — directe queries over je hele vloot               |
| **AI-Ondersteund**      | Copilot — beheer in natuurlijke taal                              |

### Kernboodschap

> **Azure Arc brengt de Azure management plane naar JOUW clusters — niet je clusters naar Azure.**  
> Dezelfde tools, dezelfde beleidsregels, dezelfde monitoring. Ongeacht waar je Kubernetes draait.

---

## Nuttige Links

- [Azure Arc-enabled Kubernetes documentatie](https://learn.microsoft.com/nl-nl/azure/azure-arc/kubernetes/)
- [K3s door Rancher](https://k3s.io/)
- [Azure Policy voor Kubernetes](https://learn.microsoft.com/nl-nl/azure/governance/policy/concepts/policy-for-kubernetes)
- [GitOps met Flux v2](https://learn.microsoft.com/nl-nl/azure/azure-arc/kubernetes/tutorial-use-gitops-flux2)
- [Container Insights voor Arc](https://learn.microsoft.com/nl-nl/azure/azure-monitor/containers/container-insights-enable-arc-enabled-clusters)
- [Defender for Containers](https://learn.microsoft.com/nl-nl/azure/defender-for-cloud/defender-for-containers-introduction)
- [Azure Developer CLI (azd)](https://learn.microsoft.com/nl-nl/azure/developer/azure-developer-cli/)
