param logicAppName string
param location string
param serviceBusNamespaceName string
param serviceBusQueueName string
param tags object

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: logicAppName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/schemas/2016-06-01/Microsoft.Logic.json'
      contentVersion: '1.0.0.0'
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
            }
          }
        }
      }
      actions: {
        enqueue_message_placeholder: {
          type: 'ApiConnection'
          inputs: {
            method: 'post'
            host: {
              connection: {
                name: '@parameters(''$connections'')[''servicebus''][''connectionId'']'
              }
            }
            path: '/@{encodeURIComponent(encodeURIComponent(''${serviceBusNamespaceName}''))}/queues/@{encodeURIComponent(''${serviceBusQueueName}'')}/messages'
            body: '@triggerBody()'
          }
        }
      }
      outputs: {}
      parameters: {
        '$connections': {
          type: 'Object'
          defaultValue: {}
        }
      }
    }
    parameters: {
      '$connections': {
        value: {}
      }
    }
  }
}

output logicAppName string = logicApp.name
output principalId string = logicApp.identity.principalId
output logicAppResourceId string = logicApp.id
