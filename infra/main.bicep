targetScope = 'subscription'

@description('Azure region for all resources')
param location string = 'centralus'

@description('Name of the resource group to create')
param resourceGroupName string = 'rg-eshop-central'

@description('PostgreSQL administrator password')
@secure()
param postgresAdminPassword string

@description('Base64-encoded PFX certificate for App Gateway HTTPS frontend')
@secure()
param sslCertificatePfxBase64 string

@description('Password for the PFX certificate')
@secure()
param sslCertificatePassword string

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
    sslCertificatePfxBase64: sslCertificatePfxBase64
    sslCertificatePassword: sslCertificatePassword
  }
}

output resourceGroupName string = rg.name
output acrLoginServer string = infra.outputs.acrLoginServer
output acrName string = infra.outputs.acrName
output containerAppsEnvironmentId string = infra.outputs.containerAppsEnvironmentId
output containerAppsEnvironmentDomain string = infra.outputs.containerAppsEnvironmentDomain
output containerAppsStaticIp string = infra.outputs.containerAppsStaticIp
output postgresServerName string = infra.outputs.postgresServerName
output postgresHost string = infra.outputs.postgresHost
output postgresAdminUser string = infra.outputs.postgresAdminUser
output redisName string = infra.outputs.redisName
output managedIdentityId string = infra.outputs.managedIdentityId
output appGatewayPublicFqdn string = infra.outputs.appGatewayPublicFqdn
output appGatewayPublicIp string = infra.outputs.appGatewayPublicIp
