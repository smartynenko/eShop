param name string
param location string

resource redis 'Microsoft.Cache/redis@2023-08-01' = {
  name: name
  location: location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
  }
}

output name string = redis.name
output host string = redis.properties.hostName
output sslPort int = redis.properties.sslPort
