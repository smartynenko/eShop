param location string
param containerAppsEnvironmentId string
param containerAppsEnvironmentDomain string
param acrLoginServer string
param managedIdentityId string
param postgresServerName string
param postgresAdminUser string
param redisName string
param imageTag string

@secure()
param postgresAdminPassword string

@secure()
param rabbitmqPassword string

// ── Reference existing resources to derive secrets ─────────────────────────

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2023-12-01' existing = {
  name: postgresServerName
}

resource redisCache 'Microsoft.Cache/redis@2023-08-01' existing = {
  name: redisName
}

// ── Connection strings ──────────────────────────────────────────────────────

var pgBase = 'Host=${postgresServer.properties.fullyQualifiedDomainName};Username=${postgresAdminUser};Password=${postgresAdminPassword};SSL Mode=Require;Trust Server Certificate=true'
var catalogDbConn   = '${pgBase};Database=catalogdb'
var identityDbConn  = '${pgBase};Database=identitydb'
var orderingDbConn  = '${pgBase};Database=orderingdb'
var webhooksDbConn  = '${pgBase};Database=webhooksdb'
var redisConnString = '${redisCache.properties.hostName}:${redisCache.properties.sslPort},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
var eventbusConn    = 'amqp://eshop:${rabbitmqPassword}@rabbitmq:5672'

// ── Public URLs (derived from well-known app names + environment domain) ────

var identityApiUrl    = 'https://identity-api.${containerAppsEnvironmentDomain}'
var webAppUrl         = 'https://webapp.${containerAppsEnvironmentDomain}'
var webhookClientUrl  = 'https://webhooksclient.${containerAppsEnvironmentDomain}'

// ── Shared ingress helper values ────────────────────────────────────────────

var dotnetPort = 8080

// ── RabbitMQ ────────────────────────────────────────────────────────────────
// Deployed as a Container App with TCP ingress so other apps can connect via AMQP.
// Internal hostname: rabbitmq:5672

resource rabbitmq 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'rabbitmq'
  location: location
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      ingress: {
        external: false
        targetPort: 5672
        transport: 'tcp'
        exposedPort: 5672
      }
    }
    template: {
      containers: [
        {
          name: 'rabbitmq'
          image: 'rabbitmq:3-management'
          resources: { cpu: json('0.5'), memory: '1Gi' }
          env: [
            { name: 'RABBITMQ_DEFAULT_USER', value: 'eshop' }
            { name: 'RABBITMQ_DEFAULT_PASS', value: rabbitmqPassword }
          ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 1 }
    }
  }
}

// ── Identity API ─────────────────────────────────────────────────────────────

resource identityApi 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'identity-api'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [{ server: acrLoginServer, identity: managedIdentityId }]
      ingress: { external: true, targetPort: dotnetPort, transport: 'auto' }
      secrets: [
        { name: 'identity-db', value: identityDbConn }
      ]
    }
    template: {
      containers: [
        {
          name: 'identity-api'
          image: '${acrLoginServer}/identity-api:${imageTag}'
          resources: { cpu: json('0.5'), memory: '1Gi' }
          env: [
            { name: 'ASPNETCORE_ENVIRONMENT', value: 'Production' }
            { name: 'ConnectionStrings__identitydb', secretRef: 'identity-db' }
            { name: 'BasketApiClient',    value: 'http://basket-api' }
            { name: 'OrderingApiClient',  value: 'http://ordering-api' }
            { name: 'WebhooksApiClient',  value: 'http://webhooks-api' }
            { name: 'WebhooksWebClient',  value: webhookClientUrl }
            { name: 'WebAppClient',       value: webAppUrl }
          ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 3 }
    }
  }
  dependsOn: [rabbitmq]
}

// ── Catalog API ───────────────────────────────────────────────────────────────

resource catalogApi 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'catalog-api'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [{ server: acrLoginServer, identity: managedIdentityId }]
      ingress: { external: false, targetPort: dotnetPort, transport: 'auto' }
      secrets: [
        { name: 'catalog-db',  value: catalogDbConn }
        { name: 'eventbus',    value: eventbusConn }
      ]
    }
    template: {
      containers: [
        {
          name: 'catalog-api'
          image: '${acrLoginServer}/catalog-api:${imageTag}'
          resources: { cpu: json('0.5'), memory: '1Gi' }
          env: [
            { name: 'ASPNETCORE_ENVIRONMENT',          value: 'Production' }
            { name: 'ConnectionStrings__catalogdb',    secretRef: 'catalog-db' }
            { name: 'ConnectionStrings__eventbus',     secretRef: 'eventbus' }
          ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 3 }
    }
  }
  dependsOn: [rabbitmq]
}

// ── Basket API (gRPC) ─────────────────────────────────────────────────────────

resource basketApi 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'basket-api'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [{ server: acrLoginServer, identity: managedIdentityId }]
      // http2 transport required for gRPC
      ingress: { external: false, targetPort: dotnetPort, transport: 'http2' }
      secrets: [
        { name: 'redis',    value: redisConnString }
        { name: 'eventbus', value: eventbusConn }
      ]
    }
    template: {
      containers: [
        {
          name: 'basket-api'
          image: '${acrLoginServer}/basket-api:${imageTag}'
          resources: { cpu: json('0.5'), memory: '1Gi' }
          env: [
            { name: 'ASPNETCORE_ENVIRONMENT',       value: 'Production' }
            { name: 'ConnectionStrings__redis',     secretRef: 'redis' }
            { name: 'ConnectionStrings__eventbus',  secretRef: 'eventbus' }
            { name: 'Identity__Url',                value: identityApiUrl }
          ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 3 }
    }
  }
  dependsOn: [rabbitmq, identityApi]
}

// ── Ordering API ──────────────────────────────────────────────────────────────

resource orderingApi 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ordering-api'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [{ server: acrLoginServer, identity: managedIdentityId }]
      ingress: { external: false, targetPort: dotnetPort, transport: 'auto' }
      secrets: [
        { name: 'ordering-db', value: orderingDbConn }
        { name: 'eventbus',    value: eventbusConn }
      ]
    }
    template: {
      containers: [
        {
          name: 'ordering-api'
          image: '${acrLoginServer}/ordering-api:${imageTag}'
          resources: { cpu: json('0.5'), memory: '1Gi' }
          env: [
            { name: 'ASPNETCORE_ENVIRONMENT',         value: 'Production' }
            { name: 'ConnectionStrings__orderingdb',  secretRef: 'ordering-db' }
            { name: 'ConnectionStrings__eventbus',    secretRef: 'eventbus' }
            { name: 'Identity__Url',                  value: identityApiUrl }
          ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 3 }
    }
  }
  dependsOn: [rabbitmq, identityApi]
}

// ── Order Processor (background worker, no ingress) ───────────────────────────

resource orderProcessor 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'order-processor'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [{ server: acrLoginServer, identity: managedIdentityId }]
      secrets: [
        { name: 'ordering-db', value: orderingDbConn }
        { name: 'eventbus',    value: eventbusConn }
      ]
    }
    template: {
      containers: [
        {
          name: 'order-processor'
          image: '${acrLoginServer}/order-processor:${imageTag}'
          resources: { cpu: json('0.25'), memory: '0.5Gi' }
          env: [
            { name: 'ASPNETCORE_ENVIRONMENT',         value: 'Production' }
            { name: 'ConnectionStrings__orderingdb',  secretRef: 'ordering-db' }
            { name: 'ConnectionStrings__eventbus',    secretRef: 'eventbus' }
          ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 1 }
    }
  }
  dependsOn: [rabbitmq, orderingApi]
}

// ── Payment Processor (background worker, no ingress) ─────────────────────────

resource paymentProcessor 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'payment-processor'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [{ server: acrLoginServer, identity: managedIdentityId }]
      secrets: [
        { name: 'eventbus', value: eventbusConn }
      ]
    }
    template: {
      containers: [
        {
          name: 'payment-processor'
          image: '${acrLoginServer}/payment-processor:${imageTag}'
          resources: { cpu: json('0.25'), memory: '0.5Gi' }
          env: [
            { name: 'ASPNETCORE_ENVIRONMENT',      value: 'Production' }
            { name: 'ConnectionStrings__eventbus', secretRef: 'eventbus' }
          ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 1 }
    }
  }
  dependsOn: [rabbitmq]
}

// ── Webhooks API ──────────────────────────────────────────────────────────────

resource webhooksApi 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'webhooks-api'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [{ server: acrLoginServer, identity: managedIdentityId }]
      ingress: { external: false, targetPort: dotnetPort, transport: 'auto' }
      secrets: [
        { name: 'webhooks-db', value: webhooksDbConn }
        { name: 'eventbus',    value: eventbusConn }
      ]
    }
    template: {
      containers: [
        {
          name: 'webhooks-api'
          image: '${acrLoginServer}/webhooks-api:${imageTag}'
          resources: { cpu: json('0.25'), memory: '0.5Gi' }
          env: [
            { name: 'ASPNETCORE_ENVIRONMENT',         value: 'Production' }
            { name: 'ConnectionStrings__webhooksdb',  secretRef: 'webhooks-db' }
            { name: 'ConnectionStrings__eventbus',    secretRef: 'eventbus' }
            { name: 'Identity__Url',                  value: identityApiUrl }
          ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 3 }
    }
  }
  dependsOn: [rabbitmq, identityApi]
}

// ── Webhook Client ────────────────────────────────────────────────────────────

resource webhookClient 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'webhooksclient'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [{ server: acrLoginServer, identity: managedIdentityId }]
      ingress: { external: true, targetPort: dotnetPort, transport: 'auto' }
    }
    template: {
      containers: [
        {
          name: 'webhooksclient'
          image: '${acrLoginServer}/webhooksclient:${imageTag}'
          resources: { cpu: json('0.25'), memory: '0.5Gi' }
          env: [
            { name: 'ASPNETCORE_ENVIRONMENT',                value: 'Production' }
            { name: 'IdentityUrl',                           value: identityApiUrl }
            { name: 'CallBackUrl',                           value: webhookClientUrl }
            { name: 'services__webhooks-api__http__0',       value: 'http://webhooks-api' }
          ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 3 }
    }
  }
  dependsOn: [webhooksApi, identityApi]
}

// ── WebApp ────────────────────────────────────────────────────────────────────

resource webApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'webapp'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironmentId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [{ server: acrLoginServer, identity: managedIdentityId }]
      ingress: { external: true, targetPort: dotnetPort, transport: 'auto' }
      secrets: [
        { name: 'eventbus', value: eventbusConn }
      ]
    }
    template: {
      containers: [
        {
          name: 'webapp'
          image: '${acrLoginServer}/webapp:${imageTag}'
          resources: { cpu: json('0.5'), memory: '1Gi' }
          env: [
            { name: 'ASPNETCORE_ENVIRONMENT',              value: 'Production' }
            { name: 'ConnectionStrings__eventbus',         secretRef: 'eventbus' }
            { name: 'IdentityUrl',                         value: identityApiUrl }
            { name: 'CallBackUrl',                         value: webAppUrl }
            { name: 'services__basket-api__http__0',       value: 'http://basket-api' }
            { name: 'services__catalog-api__http__0',      value: 'http://catalog-api' }
            { name: 'services__ordering-api__http__0',     value: 'http://ordering-api' }
          ]
        }
      ]
      scale: { minReplicas: 1, maxReplicas: 3 }
    }
  }
  dependsOn: [rabbitmq, basketApi, catalogApi, orderingApi, identityApi]
}

output webAppUrl string = 'https://${webApp.properties.configuration.ingress.fqdn}'
output identityApiUrl string = 'https://${identityApi.properties.configuration.ingress.fqdn}'
