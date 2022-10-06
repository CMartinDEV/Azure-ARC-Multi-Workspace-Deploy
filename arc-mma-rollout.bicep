targetScope = 'subscription'
param rgName string
param location string
param logAnalyticsWorkspaceName string
param windowsPolicyId string
param linuxPolicyId string
param tags object = {}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  location: location
  name: rgName  
  properties: {

  } 
  tags: tags
}

module la 'logAnalyticsWorkspace/logAnaltyics.bicep' = {
  name: '${rgName}-${logAnalyticsWorkspaceName}-deploy' 
  scope: resourceGroup(rg.name)
  params: {
    location: location
    name: logAnalyticsWorkspaceName  
  }  
}

module windowsAssignment 'policyAssignment/assignment.bicep' = {
  name: '${rgName}-${logAnalyticsWorkspaceName}-Windows-Policy-deploy'
  scope: resourceGroup(rg.name)
  params: {
    name: '${rgName}-${logAnalyticsWorkspaceName}-Windows'
    location: location
    logAnalyticsWorkspaceId: la.outputs.id
    policyId: windowsPolicyId
  }    
}

module linuxAssignment 'policyAssignment/assignment.bicep' = {
  name: '${rgName}-${logAnalyticsWorkspaceName}-Linux-Policy-deploy'
  scope: resourceGroup(rg.name)
  params: {
    name: '${rgName}-${logAnalyticsWorkspaceName}-Linux'
    location: location
    logAnalyticsWorkspaceId: la.outputs.id
    policyId: linuxPolicyId 
  }    
}
