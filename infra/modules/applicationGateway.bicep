param name string
param location string
param subnetId string

@description('FQDN of the Container Apps environment default domain (e.g. cae-eshop-xyz.centralus.azurecontainerapps.io)')
param containerAppsDefaultDomain string

@description('Static private IP of the Container Apps environment (internal load balancer)')
param containerAppsStaticIp string

var publicIpName = '${name}-pip'
var frontendIpName = 'appGwPublicFrontendIp'
var frontendPortName = 'port-443'
var httpFrontendPortName = 'port-80'
var sslCertName = 'eshop-ssl-cert'

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

resource appGateway 'Microsoft.Network/applicationGateways@2024-01-01' = {
  name: name
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
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
      {
        name: frontendPortName
        properties: { port: 443 }
      }
    ]

    // One backend pool per external-facing Container App, all pointing to the CAE internal IP
    backendAddressPools: [for backend in backends: {
      name: 'pool-${backend.name}'
      properties: {
        backendAddresses: [
          { ipAddress: containerAppsStaticIp }
        ]
      }
    }]

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

    // HTTP listener on port 80 — redirects to HTTPS
    httpListeners: concat(
      [
        {
          name: 'listener-http-redirect'
          properties: {
            frontendIPConfiguration: { id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, frontendIpName) }
            frontendPort: { id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, httpFrontendPortName) }
            protocol: 'Http'
          }
        }
      ],
      [for backend in backends: {
        name: 'listener-${backend.name}'
        properties: {
          frontendIPConfiguration: { id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', name, frontendIpName) }
          frontendPort: { id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', name, frontendPortName) }
          protocol: 'Https'
          sslCertificate: { id: resourceId('Microsoft.Network/applicationGateways/sslCertificates', name, sslCertName) }
          hostName: backend.hostname
        }
      }]
    )

    // SSL certificate placeholder — replace with Key Vault reference or PFX for production
    sslCertificates: [
      {
        name: sslCertName
        properties: {
          // TODO: Replace with Key Vault secret ID for production:
          // keyVaultSecretId: 'https://<vault-name>.vault.azure.net/secrets/<cert-name>'
          data: ''
          password: ''
        }
      }
    ]

    redirectConfigurations: [
      {
        name: 'redirect-http-to-https'
        properties: {
          redirectType: 'Permanent'
          targetListener: { id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, 'listener-${backends[0].name}') }
          includePath: true
          includeQueryString: true
        }
      }
    ]

    requestRoutingRules: concat(
      [
        {
          name: 'rule-http-redirect'
          properties: {
            priority: 100
            ruleType: 'Basic'
            httpListener: { id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, 'listener-http-redirect') }
            redirectConfiguration: { id: resourceId('Microsoft.Network/applicationGateways/redirectConfigurations', name, 'redirect-http-to-https') }
          }
        }
      ],
      [for (backend, i) in backends: {
        name: 'rule-${backend.name}'
        properties: {
          priority: 200 + i
          ruleType: 'Basic'
          httpListener: { id: resourceId('Microsoft.Network/applicationGateways/httpListeners', name, 'listener-${backend.name}') }
          backendAddressPool: { id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', name, 'pool-${backend.name}') }
          backendHttpSettings: { id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', name, 'settings-${backend.name}') }
        }
      }]
    )

    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
  }
}

output publicIpAddress string = publicIp.properties.ipAddress
output publicFqdn string = publicIp.properties.dnsSettings.fqdn
output appGatewayId string = appGateway.id
