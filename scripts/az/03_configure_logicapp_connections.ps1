param(
  [Parameter(Mandatory = $true)][string]$ResourceGroup,
  [Parameter(Mandatory = $true)][string]$LogicAppName,
  [Parameter(Mandatory = $true)][string]$ServiceBusConnectionResourceId,
  [Parameter(Mandatory = $true)][string]$OfficeConnectionResourceId
)

$connections = @{
  value = @{
    servicebus = @{
      connectionId = $ServiceBusConnectionResourceId
      connectionName = "servicebus"
      id = "/subscriptions/$((az account show --query id -o tsv))/providers/Microsoft.Web/locations/$((az group show -n $ResourceGroup --query location -o tsv))/managedApis/servicebus"
    }
    office365 = @{
      connectionId = $OfficeConnectionResourceId
      connectionName = "office365"
      id = "/subscriptions/$((az account show --query id -o tsv))/providers/Microsoft.Web/locations/$((az group show -n $ResourceGroup --query location -o tsv))/managedApis/office365"
    }
  }
}

$payload = @{
  properties = @{
    parameters = @{
      '$connections' = $connections
    }
  }
} | ConvertTo-Json -Depth 10

az resource update `
  --resource-group $ResourceGroup `
  --name $LogicAppName `
  --resource-type Microsoft.Logic/workflows `
  --set properties.parameters.'$connections'="$($connections | ConvertTo-Json -Depth 10)"
