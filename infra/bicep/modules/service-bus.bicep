param namespaceName string
param queueName string
param location string
param tags object

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2023-01-01-preview' = {
  name: namespaceName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  tags: tags
}

resource queue 'Microsoft.ServiceBus/namespaces/queues@2023-01-01-preview' = {
  parent: serviceBusNamespace
  name: queueName
  properties: {
    maxDeliveryCount: 10
    deadLetteringOnMessageExpiration: true
    lockDuration: 'PT2M'
    defaultMessageTimeToLive: 'P14D'
  }
}

output queueName string = queue.name
output queueResourceId string = queue.id
output namespaceName string = serviceBusNamespace.name
output namespaceResourceId string = serviceBusNamespace.id
