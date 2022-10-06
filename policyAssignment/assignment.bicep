param name string
param logAnalyticsWorkspaceId string
param location string
param policyId string

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2021-06-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned' 
  }
  properties: {
    displayName: name
    policyDefinitionId: policyId 
    parameters: {
      logAnalytics: {
        value: logAnalyticsWorkspaceId
      }
    }   
  }     
}
