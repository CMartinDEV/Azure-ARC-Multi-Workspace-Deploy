param name string
param roleDefinitionId string
param objectId string

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(subscription().id,resourceGroup().name,name)
  properties: { 
    roleDefinitionId: roleDefinitionId
    principalId: objectId 
    principalType: 'ServicePrincipal'
  }
}
