param name string
param location string
param logAnalyticsWorkspaceId string

@secure()
param logAnalyticsWorkspaceKey string

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspaceId
        sharedKey: logAnalyticsWorkspaceKey
      }
    }
  }
}

output environmentId string = environment.id
output defaultDomain string = environment.properties.defaultDomain
