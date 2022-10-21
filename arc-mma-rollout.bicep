targetScope = 'subscription'
param rgName string
param location string
param logAnalyticsWorkspaceName string
param storageAccountName string
param windowsPolicyId string
param linuxPolicyId string
param enableExport bool
param tags object = {}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  location: location
  name: rgName  
  properties: {

  } 
  tags: tags
}

module logAnalyticsWithSentinel 'sentinel/logAnalytics-with-Sentinel.bicep' = {
  name: '${rgName}-${logAnalyticsWorkspaceName}-deploy' 
  scope: resourceGroup(rg.name)
  params: {
    location: location
    name: logAnalyticsWorkspaceName  
    saId: storageAccount.outputs.saId
    enableDataExport: enableExport
  }  
}

module storageAccount 'storageAccount/storageAccount.bicep' = {
  name: '${rgName}-${storageAccountName}-Storage-Account-deploy'
  scope: resourceGroup(rg.name)
  params: {
    name: storageAccountName
    location: location
  }
}

module windowsPolicyAssignment 'policyAssignment/assignment.bicep' = {
  name: '${rgName}-${logAnalyticsWorkspaceName}-Windows-Policy-deploy'
  scope: resourceGroup(rg.name)
  params: {
    name: '${rgName}-${logAnalyticsWorkspaceName}-Windows'
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWithSentinel.outputs.id
    policyId: windowsPolicyId
  }    
}

module linuxPolicyAssignment 'policyAssignment/assignment.bicep' = {
  name: '${rgName}-${logAnalyticsWorkspaceName}-Linux-Policy-deploy'
  scope: resourceGroup(rg.name)
  params: {
    name: '${rgName}-${logAnalyticsWorkspaceName}-Linux'
    location: location
    logAnalyticsWorkspaceId: logAnalyticsWithSentinel.outputs.id
    policyId: linuxPolicyId 
  }    
}

module grantWindowsPolicyLogAnalyticsContributor 'rbacAssignment/rbacAssignment.bicep' = {
  name: 'Windows-Role-Assignment'
  scope: resourceGroup(rg.name)
  params: {
    name: 'windowsRbac'
    objectId: windowsPolicyAssignment.outputs.smi
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'   
  }
}

module grantLinuxPolicyLogAnalyticsContributor 'rbacAssignment/rbacAssignment.bicep' = {
  name: 'Linux-Role-Assignment'
  scope: resourceGroup(rg.name)
  params: {
    name: 'linuxRbac'
    objectId: linuxPolicyAssignment.outputs.smi
    roleDefinitionId: '/providers/Microsoft.Authorization/roleDefinitions/92aaf0da-9dab-42b6-94a3-d43ce8d16293'   
  }
}
