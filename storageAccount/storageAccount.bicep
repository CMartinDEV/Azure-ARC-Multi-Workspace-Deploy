param name string
param location string


resource sa 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  kind: 'StorageV2'
  location: location
  name: name
  sku: {
    name: 'Standard_LRS'
  }
}

output saId string = sa.id
