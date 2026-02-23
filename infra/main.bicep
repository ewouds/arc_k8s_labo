// ============================================================================
// Main Bicep - Azure Arc-enabled Kubernetes Workshop
// ============================================================================
// This template deploys:
//   1. Resource Group
//   2. Virtual Network + NSG + Public IP  (simulates "on-prem" network)
//   3. Ubuntu VM                          (will run K3s / Rancher)
//   4. Log Analytics Workspace            (for monitoring & Defender)
//
// Usage:  azd provision   (or azd up)
// ============================================================================

targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Parameters - AZD will prompt for these during `azd provision`
// ---------------------------------------------------------------------------

@minLength(1)
@maxLength(64)
@description('Name of the environment (used as prefix for all resources)')
param environmentName string

@description('Primary location for all resources')
param location string

@description('Admin username for the K3s VM')
param vmAdminUsername string = 'azureuser'

@secure()
@minLength(12)
@description('Admin password for the K3s VM (min 12 chars, must include uppercase, lowercase, number, special char)')
param vmAdminPassword string

@description('VM size for the K3s node')
param vmSize string = 'Standard_D2s_v3'

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------

var namePrefix = 'arc-${environmentName}'
var tags = {
  'azd-env-name': environmentName
  purpose: 'arc-k8s-workshop'
}

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${environmentName}'
  location: location
  tags: tags
}

// ---------------------------------------------------------------------------
// Modules
// ---------------------------------------------------------------------------

// 1. Networking (VNet, Subnet, NSG, Public IP)
module network 'modules/network.bicep' = {
  scope: rg
  name: 'network-deployment'
  params: {
    location: location
    namePrefix: namePrefix
  }
}

// 2. Ubuntu VM (K3s host)
module vm 'modules/vm.bicep' = {
  scope: rg
  name: 'vm-deployment'
  params: {
    location: location
    namePrefix: namePrefix
    subnetId: network.outputs.subnetId
    publicIpId: network.outputs.publicIpId
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    vmSize: vmSize
  }
}

// 3. Log Analytics Workspace (for monitoring, Defender, Container Insights)
module logAnalytics 'modules/loganalytics.bicep' = {
  scope: rg
  name: 'loganalytics-deployment'
  params: {
    location: location
    namePrefix: namePrefix
  }
}

// ---------------------------------------------------------------------------
// Outputs - Used by scripts and displayed after `azd provision`
// ---------------------------------------------------------------------------

output AZURE_RESOURCE_GROUP string = rg.name
output VM_PUBLIC_IP string = network.outputs.publicIpAddress
output VM_FQDN string = network.outputs.fqdn
output VM_ADMIN_USERNAME string = vmAdminUsername
output VM_NAME string = vm.outputs.vmName
output LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.outputs.workspaceId
output LOG_ANALYTICS_WORKSPACE_NAME string = logAnalytics.outputs.workspaceName
output SSH_COMMAND string = 'ssh ${vmAdminUsername}@${network.outputs.publicIpAddress}'
