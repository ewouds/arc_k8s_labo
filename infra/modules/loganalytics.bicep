// ============================================================================
// Log Analytics Module - Central workspace for monitoring & observability
// Used by Container Insights, Defender, and Azure Monitor
// ============================================================================

param location string
param namePrefix string

// --- Log Analytics Workspace ---
resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${namePrefix}-law'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
}

// --- Outputs ---
output workspaceId string = workspace.id
output workspaceName string = workspace.name
output workspaceCustomerId string = workspace.properties.customerId
