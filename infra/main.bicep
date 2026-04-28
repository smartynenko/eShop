targetScope = 'subscription'

@description('Azure region for all resources')
param location string = 'centralus'

@description('Name of the resource group to create')
param resourceGroupName string = 'rg-eshop-central'

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: {
    application: 'eShop'
  }
}

module infra 'infra.bicep' = {
  name: 'eshop-infra'
  scope: rg
  params: {
    location: location
    postgresAdminPassword: postgresAdminPassword
  }
}

output resourceGroupName string = rg.name
output acrLoginServer string = infra.outputs.acrLoginServer
output acrName string = infra.outputs.acrName
output containerAppsEnvironmentId string = infra.outputs.containerAppsEnvironmentId
output containerAppsEnvironmentDomain string = infra.outputs.containerAppsEnvironmentDomain
output postgresServerName string = infra.outputs.postgresServerName
output postgresHost string = infra.outputs.postgresHost
output postgresAdminUser string = infra.outputs.postgresAdminUser
output redisName string = infra.outputs.redisName
output managedIdentityId string = infra.outputs.managedIdentityId
