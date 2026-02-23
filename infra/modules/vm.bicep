// ============================================================================
// VM Module - Ubuntu VM simulating an "on-premises" server running K3s
// ============================================================================

param location string
param namePrefix string
param subnetId string
param publicIpId string
param adminUsername string

@secure()
param adminPassword string

param vmSize string = 'Standard_D2s_v3'

// --- Network Interface ---
resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: '${namePrefix}-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
          publicIPAddress: {
            id: publicIpId
          }
        }
      }
    ]
  }
}

// --- Virtual Machine ---
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: '${namePrefix}-vm'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: '${namePrefix}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 64
      }
    }
    osProfile: {
      computerName: 'k3s-node'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

// --- Outputs ---
output vmId string = vm.id
output vmName string = vm.name
