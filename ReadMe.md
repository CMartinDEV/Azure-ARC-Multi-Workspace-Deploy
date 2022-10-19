# What does this do?
Deploys Resources Groups, Workspaces, and Storage Accounts designed to be targets for Azure Arc Server registrations.  
Each resource group has a policy assignment to deploy Log Analytics Agents to any registered servers.  
Microsoft Sentinel is deployed and enabled to receive log data from the Security Events via Legacy Connector Data Connector for each Log Analytics workspace.  
A storage account is provisioned for each resource group to be linked to Log Analytics for long-term log retention.  

# Requirements
Az.Accounts PowerShell module  
Az.Resources PowerShell module  
Bicep must be installed  
https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#azure-powershell  

# Example

PowerShell example without Output  

```Powershell
.\Invoke-MSSentinelOnLogAnalyticsDeployment.ps1 -Path .\csvExample.csv -SubscriptionId cdb7af97-3849-4890-9a92-e5bbbadbd239 -Location "eastus"
```

PowerShell example with Output  

```Powershell
.\Invoke-MSSentinelOnLogAnalyticsDeployment.ps1 -Path .\csvExample.csv -OutputPath .\ArcOnboardScripts.zip -TenantId 364426d1-acb8-4a1c-9e64-d3311727b763 -SubscriptionId cdb7af97-3849-4890-9a92-e5bbbadbd239 -Location "eastus" -ApplicationCredential $appCredential
```

CSV Example  

Columns are RGName, WorkspaceName, StorageAccountName. Do not use headers.  

```CSV
rg_arc_law_1,arc-law-1,samyorgarclaw1
rg_arc_law_2,arc-law-2,samyorgarclaw2
rg_arc_law_3,arc-law-3,samyorgarclaw3
```