param name string
param location string

resource la 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  location: location
  name: name  
}

resource solutionsAzureSentinel 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'SecurityInsights(${la.name})'
  location: location
  properties: {
    workspaceResourceId: la.id
  }
  plan: {
    name: 'SecurityInsights(${la.name})'
    publisher: 'Microsoft'
    product: 'OMSGallery/SecurityInsights'
    promotionCode: ''
  }
}

output id string = la.id
