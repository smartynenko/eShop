param name string
param location string
param subnetId string

@description('FQDN of the Container Apps environment default domain (e.g. cae-eshop-xyz.centralus.azurecontainerapps.io)')
param containerAppsDefaultDomain string

@description('Static private IP of the Container Apps environment (internal load balancer)')
param containerAppsStaticIp string

var publicIpName = '${name}-pip'
var frontendIpName = 'appGwPublicFrontendIp'
var httpFrontendPortName = 'port-80'

var webappHostname        = 'webapp.${containerAppsDefaultDomain}'
var identityApiHostname   = 'identity-api.${containerAppsDefaultDomain}'
var webhookClientHostname = 'webhooksclient.${containerAppsDefaultDomain}'
var mobileBffHostname     = 'mobile-bff.${containerAppsDefaultDomain}'

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: publicIpName
  location: location
  sku: { name: 'Standard' }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: name
    }
  }
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-01-01' = {
  name: '${name}-waf-policy'
  location: location
  properties: {
    policySettings: {
      state: 'Enabled'
      mode: 'Prevention'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
  }
}

resource appGateway 'Microsoft.Network/applicationGateways@2024-01-01' = {
  name: name
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    firewallPolicy: {
      id: wafPolicy.id
    }
    autoscaleConfiguration: {
      minCapacity: 1
      maxCapacity: 3
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: { id: subnetId }
        }
      }
    ]

    frontendIPConfigurations: [
      {
        name: frontendIpName
        properties: {
          publicIPAddress: { id: publicIp.id }
        }
      }
    ]

    frontendPorts: [
      {
        name: httpFrontendPortName
        properties: { port: 80 }
      }
    ]

    backendAddressPools: [
      {
        name: 'pool-webapp'
        properties: {
          backendAddresses: [
            { fqdn: webappHostname }
          ]
        }
      }
      {
        name: 'pool-identity-api'
        properties: {
          backendAddresses: [
            { fqdn: identityApiHostname }
          ]
        }
      }
      {
        name: 'pool-webhooksclient'
        properties: {
          backendAddresses: [
            { fqdn: webhookClientHostname }
          ]
        }
      }
      {
        name: 'pool-mobile-bff'
        properties: {
          backendAddresses: [
            { fqdn: mobileBffHostname }
          ]
        }
      }
    ]

    // Backend pools use FQDNs resolved via Private DNS → CAE static IP.
    // pickHostNameFromBackendAddress sends the correct Host header for Envoy routing.
    backendHttpSettingsCollection: [
      {
        name: 'settings-webapp'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
          probe: { id: resourceId('Microsoft.Network/applicationGateways/probes', name, 'probe-webapp') }
        }
      }
      {
        name: 'settings-identity-api'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
          probe: { id: resourceId('Microsoft.Network/applicationGateways/probes', name, 'probe-identity-api') }
        }
      }
      {
        name: 'settings-webhooksclient'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
          probe: { id: resourceId('Microsoft.Network/applicationGateways/probes', name, 'probe-webhooksclient') }
        }
      }
      {
        name: 'settings-mobile-bff'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
          probe: { id: resourceId('Microsoft.Network/applicationGateways/probes', name, 'probe-mobile-bff') }
        }
      }
    ]

    probes: [
      {
        name: 'probe-webapp'
        properties: {
          protocol: 'Https'
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
        }
      }
      {
        name: 'probe-identity-api'
        properties: {
          protocol: 'Https'
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
        }
      }
      {
        name: 'probe-webhooksclient'
        properties: {
          protocol: 'Https'
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
        }
      }
      {
        name: 'probe-mobile-bff'
        properties: {
          protocol: 'Https'
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
        }
      }
    ]

    // Single default listener — no hostName filter, accepts any request on port 80.
    // Routes all traffic to the webapp backend (the main public entry point).
    // Path-based routing can be added later to split /api/identity, /webhooks, etc.
    httpListeners: [
      {
        name: 'listener-default'
        properties: {
          frontendIPConfiguration: { id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, frontendIpName) }
          frontendPort: { id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, httpFrontendPortName) }
          protocol: 'Http'
        }
      }
    ]

    requestRoutingRules: [
      {
        name: 'rule-default-to-webapp'
        properties: {
          priority: 100
          ruleType: 'Basic'
          httpListener: { id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, 'listener-default') }
          backendAddressPool: { id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, 'pool-webapp') }
          backendHttpSettings: { id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, 'settings-webapp') }
        }
      }
    ]
  }
}

output publicIpAddress string = publicIp.properties.ipAddress
output publicFqdn string = publicIp.properties.dnsSettings.fqdn
output appGatewayId string = appGateway.id
