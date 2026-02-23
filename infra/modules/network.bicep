// ============================================================================
// Network Module - VNet, Subnet, NSG, Public IP
// Simulates an "on-premises" network for the K3s VM
// ============================================================================

param location string
param namePrefix string

// --- Network Security Group ---
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: '${namePrefix}-nsg'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Allow SSH access for K3s management'
        }
      }
      {
        name: 'AllowHTTPS'
        properties: {
          priority: 1100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Allow HTTPS for Arc agent communication'
        }
      }
      {
        name: 'AllowK8sAPI'
        properties: {
          priority: 1200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '6443'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          description: 'Allow Kubernetes API server access'
        }
      }
    ]
  }
}

// --- Virtual Network ---
resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: '${namePrefix}-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// --- Public IP Address ---
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: '${namePrefix}-pip'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: '${namePrefix}-k3s'
    }
  }
}

// --- Outputs ---
output subnetId string = vnet.properties.subnets[0].id
output publicIpId string = publicIp.id
output publicIpAddress string = publicIp.properties.ipAddress
output fqdn string = publicIp.properties.dnsSettings.fqdn
