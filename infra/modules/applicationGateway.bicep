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

// Backend targets: external-facing Container Apps
var backends = [
  { name: 'webapp',         hostname: 'webapp.${containerAppsDefaultDomain}' }
  { name: 'identity-api',   hostname: 'identity-api.${containerAppsDefaultDomain}' }
  { name: 'webhooksclient', hostname: 'webhooksclient.${containerAppsDefaultDomain}' }
  { name: 'mobile-bff',     hostname: 'mobile-bff.${containerAppsDefaultDomain}' }
]

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

// Pre-compute loop-generated arrays — Bicep does not allow for-expressions inside concat() in resource properties
var backendListeners = [for backend in backends: {
  name: 'listener-${backend.name}'
  properties: {
    frontendIPConfiguration: { id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, frontendIpName) }
    frontendPort: { id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, httpFrontendPortName) }
    protocol: 'Http'
    hostName: backend.hostname
  }
}]

var backendRoutingRules = [for (backend, i) in backends: {
  name: 'rule-${backend.name}'
  properties: {
    priority: 200 + i
    ruleType: 'Basic'
    httpListener: { id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, 'listener-${backend.name}') }
    backendAddressPool: { id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, 'pool-${backend.name}') }
    backendHttpSettings: { id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, 'settings-${backend.name}') }
  }
}]

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

    backendAddressPools: [for backend in backends: {
      name: 'pool-${backend.name}'
      properties: {
        backendAddresses: [
          { ipAddress: containerAppsStaticIp }
        ]
      }
    }]

    // Backend connections use HTTPS to the Container Apps internal endpoints
    backendHttpSettingsCollection: [for backend in backends: {
      name: 'settings-${backend.name}'
      properties: {
        port: 443
        protocol: 'Https'
        cookieBasedAffinity: 'Disabled'
        requestTimeout: 30
        pickHostNameFromBackendAddress: false
        hostName: backend.hostname
        probe: { id: resourceId('Microsoft.Network/applicationGateways/probes', name, 'probe-${backend.name}') }
      }
    }]

    probes: [for backend in backends: {
      name: 'probe-${backend.name}'
      properties: {
        protocol: 'Https'
        host: backend.hostname
        path: '/health'
        interval: 30
        timeout: 30
        unhealthyThreshold: 3
        pickHostNameFromBackendHttpSettings: false
      }
    }]

    // Frontend listeners on HTTP (port 80) with host-based routing
    // TODO: Add HTTPS (port 443) listeners with a Key Vault certificate for production
    httpListeners: backendListeners

    requestRoutingRules: backendRoutingRules
  }
}

output publicIpAddress string = publicIp.properties.ipAddress
output publicFqdn string = publicIp.properties.dnsSettings.fqdn
output appGatewayId string = appGateway.id
