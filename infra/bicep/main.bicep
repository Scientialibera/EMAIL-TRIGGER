targetScope = 'resourceGroup'

@description('Environment suffix (for example dev/test/prod)')
param environment string = 'dev'

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Base name prefix')
param baseName string = 'cqc-email'

@description('Deploy Key Vault or not')
param enableKeyVault bool = true

@description('Tags applied to all resources')
param tags object = {
  solution: 'cqc-email-processor'
  env: environment
}

@description('Name of Service Bus queue used by processing function')
param serviceBusQueueName string = 'q-cqc-email-process'

@description('Azure OpenAI resource ID (existing)')
param aoaiResourceId string

@description('Document Intelligence resource ID (existing)')
param docIntelResourceId string

@description('Optional custom role definition for AOAI invoke. Leave empty to skip.')
param aoaiInvokeRoleDefinitionId string = ''

@description('Optional custom role definition for Document Intelligence invoke. Leave empty to skip.')
param docIntelInvokeRoleDefinitionId string = ''

@description('Optional custom role definition for Fabric access. Leave empty to skip (handled outside Azure RBAC).')
param fabricRoleDefinitionId string = ''

@description('Optional role definition for Key Vault Secrets User.')
param keyVaultSecretsUserRoleDefinitionId string = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '4633458b-17de-408a-b874-0445c86b69e6'
)

var storageAccountName = toLower('st${replace(baseName, '-', '')}${environment}')
var appInsightsName = 'appi-${baseName}-${environment}'
var logAnalyticsName = 'law-${baseName}-${environment}'
var serviceBusNamespaceName = 'sbns-${baseName}-${environment}'
var functionPlanName = 'asp-${baseName}-${environment}'
var functionAppName = 'func-${baseName}-${environment}'
var logicAppName = 'la-${baseName}-${environment}'
var keyVaultName = toLower('kv-${baseName}-${environment}')

module observability './modules/observability.bicep' = {
  name: 'deploy-observability'
  params: {
    appInsightsName: appInsightsName
    logAnalyticsName: logAnalyticsName
    location: location
    tags: tags
  }
}

module storage './modules/storage.bicep' = {
  name: 'deploy-storage'
  params: {
    storageAccountName: storageAccountName
    location: location
    tags: tags
  }
}

module serviceBus './modules/service-bus.bicep' = {
  name: 'deploy-servicebus'
  params: {
    namespaceName: serviceBusNamespaceName
    queueName: serviceBusQueueName
    location: location
    tags: tags
  }
}

module functionApp './modules/function-app.bicep' = {
  name: 'deploy-functionapp'
  params: {
    functionPlanName: functionPlanName
    functionAppName: functionAppName
    location: location
    storageAccountName: storage.outputs.storageAccountName
    appInsightsConnectionString: observability.outputs.appInsightsConnectionString
    tags: tags
  }
}

module logicApp './modules/logic-app.bicep' = {
  name: 'deploy-logicapp'
  params: {
    logicAppName: logicAppName
    location: location
    serviceBusQueueName: serviceBusQueueName
    serviceBusNamespaceName: serviceBusNamespaceName
    tags: tags
  }
}

module keyVault './modules/key-vault.bicep' = if (enableKeyVault) {
  name: 'deploy-keyvault'
  params: {
    keyVaultName: keyVaultName
    location: location
    tags: tags
  }
}

module rbacLogicToSb './modules/role-assignment.bicep' = {
  name: 'rbac-logic-sb-sender'
  scope: resourceGroup()
  params: {
    principalId: logicApp.outputs.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
    )
    targetResourceId: serviceBus.outputs.queueResourceId
  }
}

module rbacFuncToSb './modules/role-assignment.bicep' = {
  name: 'rbac-func-sb-receiver'
  scope: resourceGroup()
  params: {
    principalId: functionApp.outputs.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4f6d3b9b-027b-4f4c-a5f9-4f8e52f4f0d2'
    )
    targetResourceId: serviceBus.outputs.queueResourceId
  }
}

module rbacFuncToAoai './modules/role-assignment.bicep' = if (!empty(aoaiInvokeRoleDefinitionId)) {
  name: 'rbac-func-aoai-invoke'
  scope: resourceGroup()
  params: {
    principalId: functionApp.outputs.principalId
    roleDefinitionId: aoaiInvokeRoleDefinitionId
    targetResourceId: aoaiResourceId
  }
}

module rbacFuncToDocIntel './modules/role-assignment.bicep' = if (!empty(docIntelInvokeRoleDefinitionId)) {
  name: 'rbac-func-docintel-invoke'
  scope: resourceGroup()
  params: {
    principalId: functionApp.outputs.principalId
    roleDefinitionId: docIntelInvokeRoleDefinitionId
    targetResourceId: docIntelResourceId
  }
}

module rbacFuncToKv './modules/role-assignment.bicep' = if (enableKeyVault) {
  name: 'rbac-func-kv-secrets'
  scope: resourceGroup()
  params: {
    principalId: functionApp.outputs.principalId
    roleDefinitionId: keyVaultSecretsUserRoleDefinitionId
    targetResourceId: keyVault.outputs.keyVaultResourceId
  }
}

output functionAppName string = functionApp.outputs.functionAppName
output functionPrincipalId string = functionApp.outputs.principalId
output logicAppName string = logicApp.outputs.logicAppName
output logicAppPrincipalId string = logicApp.outputs.principalId
output serviceBusQueueName string = serviceBus.outputs.queueName
output serviceBusQueueResourceId string = serviceBus.outputs.queueResourceId
output keyVaultName string = enableKeyVault ? keyVault.outputs.keyVaultName : ''
