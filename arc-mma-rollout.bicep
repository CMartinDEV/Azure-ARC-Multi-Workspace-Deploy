targetScope = 'subscription'
param rgName string
param location string
param logAnalyticsWorkspaceName string
param storageAccountName string
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

module la 'logAnalyticsWorkspace/logAnalytics.bicep' = {
  name: '${rgName}-${logAnalyticsWorkspaceName}-deploy' 
  scope: resourceGroup(rg.name)
  params: {
    location: location
    name: logAnalyticsWorkspaceName  
    saId: storageAccount.outputs.saId
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

module windowsRbac 'rbacAssignment/rbacAssignment.bicep' = {
  name: 'Windows-Role-Assignment'
  scope: resourceGroup(rg.name)
  params: {
    name: 'windowsRbac'
    objectId: windowsAssignment.outputs.smi
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'   
  }
}

module linuxRbac 'rbacAssignment/rbacAssignment.bicep' = {
  name: 'Linux-Role-Assignment'
  scope: resourceGroup(rg.name)
  params: {
    name: 'linuxRbac'
    objectId: linuxAssignment.outputs.smi
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'   
  }
}

module storageAccount 'storageAccount/storageAccount.bicep' = {
  name: uniqueString(logAnalyticsWorkspaceName)
  scope: resourceGroup(rg.name)
  params: {
    name: storageAccountName
    location: location
  }
}



