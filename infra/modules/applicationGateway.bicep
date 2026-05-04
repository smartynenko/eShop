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
            { ipAddress: containerAppsStaticIp }
          ]
        }
      }
      {
        name: 'pool-identity-api'
        properties: {
          backendAddresses: [
            { ipAddress: containerAppsStaticIp }
          ]
        }
      }
      {
        name: 'pool-webhooksclient'
        properties: {
          backendAddresses: [
            { ipAddress: containerAppsStaticIp }
          ]
        }
      }
      {
        name: 'pool-mobile-bff'
        properties: {
          backendAddresses: [
            { ipAddress: containerAppsStaticIp }
          ]
        }
      }
    ]

    // Backend connections use HTTPS to the Container Apps internal endpoints.
    // hostName overrides the Host header so the CAE internal LB routes to the correct app.
    backendHttpSettingsCollection: [
      {
        name: 'settings-webapp'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: false
          hostName: webappHostname
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
          pickHostNameFromBackendAddress: false
          hostName: identityApiHostname
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
          pickHostNameFromBackendAddress: false
          hostName: webhookClientHostname
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
          pickHostNameFromBackendAddress: false
          hostName: mobileBffHostname
          probe: { id: resourceId('Microsoft.Network/applicationGateways/probes', name, 'probe-mobile-bff') }
        }
      }
    ]

    probes: [
      {
        name: 'probe-webapp'
        properties: {
          protocol: 'Https'
          host: webappHostname
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
        }
      }
      {
        name: 'probe-identity-api'
        properties: {
          protocol: 'Https'
          host: identityApiHostname
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
        }
      }
      {
        name: 'probe-webhooksclient'
        properties: {
          protocol: 'Https'
          host: webhookClientHostname
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
        }
      }
      {
        name: 'probe-mobile-bff'
        properties: {
          protocol: 'Https'
          host: mobileBffHostname
          path: '/health'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
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
