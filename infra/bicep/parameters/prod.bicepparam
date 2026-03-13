using '../main.bicep'

param environment = 'prod'
param location = 'eastus2'
param baseName = 'cqc-email'
param enableKeyVault = true
param serviceBusQueueName = 'q-cqc-email-process'
param aoaiResourceId = '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<aoai-account>'
param docIntelResourceId = '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<docintel-account>'
param aoaiInvokeRoleDefinitionId = ''
param docIntelInvokeRoleDefinitionId = ''
param fabricRoleDefinitionId = ''
