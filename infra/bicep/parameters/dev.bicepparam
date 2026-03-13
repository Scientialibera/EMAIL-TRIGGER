using '../main.bicep'

param environment = 'dev'
param location = 'eastus2'
param baseName = 'cqc-email'
param enableKeyVault = true
param serviceBusQueueName = 'q-cqc-email-process'
param fabricWriteQueueName = 'q-cqc-fabric-write'

// Replace with actual existing resource IDs in your subscription.
param aoaiResourceId = '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<aoai-account>'
param docIntelResourceId = '/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.CognitiveServices/accounts/<docintel-account>'

// Optional: set exact custom role definitions or leave empty to skip.
param aoaiInvokeRoleDefinitionId = ''
param docIntelInvokeRoleDefinitionId = ''
param fabricRoleDefinitionId = ''
