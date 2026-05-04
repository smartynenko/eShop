param location string

@secure()
param postgresAdminPassword string

var suffix = uniqueString(resourceGroup().id)
var postgresAdminUser = 'eshopAdmin'

module logAnalytics 'modules/logAnalytics.bicep' = {
  name: 'logAnalytics'
  params: {
    name: 'log-eshop-${suffix}'
    location: location
  }
}

module acr 'modules/containerRegistry.bicep' = {
  name: 'acr'
  params: {
    name: 'acreshop${suffix}'
    location: location
  }
}

module vnet 'modules/virtualNetwork.bicep' = {
  name: 'vnet'
  params: {
    name: 'vnet-eshop-${suffix}'
    location: location
  }
}

// Use the known name (derived from suffix) so listKeys() can be resolved at deployment time
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: 'log-eshop-${suffix}'
  dependsOn: [logAnalytics]
}

module containerAppsEnv 'modules/containerAppsEnvironment.bicep' = {
  name: 'containerAppsEnv'
  params: {
    name: 'cae-eshop-${suffix}'
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
    logAnalyticsWorkspaceKey: logAnalyticsWorkspace.listKeys().primarySharedKey
    containerAppsSubnetId: vnet.outputs.containerAppsSubnetId
  }
}

module privateDns 'modules/privateDnsZone.bicep' = {
  name: 'privateDns'
  params: {
    containerAppsDefaultDomain: containerAppsEnv.outputs.defaultDomain
    containerAppsStaticIp: containerAppsEnv.outputs.staticIp
    vnetId: vnet.outputs.vnetId
  }
}

module appGateway 'modules/applicationGateway.bicep' = {
  name: 'appGateway'
  params: {
    name: 'agw-eshop-${suffix}'
    location: location
    subnetId: vnet.outputs.appGatewaySubnetId
    containerAppsDefaultDomain: containerAppsEnv.outputs.defaultDomain
    containerAppsStaticIp: containerAppsEnv.outputs.staticIp
  }
  dependsOn: [privateDns]
}

module postgres 'modules/postgres.bicep' = {
  name: 'postgres'
  params: {
    serverName: 'psql-eshop-${suffix}'
    location: location
    adminUser: postgresAdminUser
    adminPassword: postgresAdminPassword
  }
}

module redis 'modules/redis.bicep' = {
  name: 'redis'
  params: {
    name: 'redis-eshop-${suffix}'
    location: location
  }
}

// User-assigned managed identity for Container Apps to pull from ACR
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-eshop-${suffix}'
  location: location
}

// Grant the managed identity AcrPull on the container registry
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
resource acrResource 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: 'acreshop${suffix}'
  dependsOn: [acr]
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrResource.id, managedIdentity.id, acrPullRoleId)
  scope: acrResource
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output acrLoginServer string = acr.outputs.loginServer
output acrName string = acr.outputs.name
output containerAppsEnvironmentId string = containerAppsEnv.outputs.environmentId
output containerAppsEnvironmentDomain string = containerAppsEnv.outputs.defaultDomain
output containerAppsStaticIp string = containerAppsEnv.outputs.staticIp
output postgresServerName string = 'psql-eshop-${suffix}'
output postgresHost string = postgres.outputs.host
output postgresAdminUser string = postgresAdminUser
output redisName string = redis.outputs.name
output managedIdentityId string = managedIdentity.id
output managedIdentityName string = managedIdentity.name
output appGatewayPublicFqdn string = appGateway.outputs.publicFqdn
output appGatewayPublicIp string = appGateway.outputs.publicIpAddress
