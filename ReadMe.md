# What does this do?
Deploys Resources Groups, Workspaces, and Storage Accounts designed to be targets for Azure Arc Server registrations.  
Each resource group has a policy assignment to deploy Log Analytics Agents to any registered servers.
A storage account is provisioned for each resource group to be linked to Log Analytics for long-term log retention.

# Requirements
Az.Accounts PowerShell module
Az.Resources PowerShell module

# Example

```Powershell
.\Deploy.ps1 -Path .\csvExample.csv -SubscriptionId 32eb88b4-0000-0000-85e3-ec8b7ce1fc00 -Location "eastus"
```

```CSV
rg_arc_law_1,arc_law_1,samyorgarclaw1
rg_arc_law_2,arc_law_2,samyorgarclaw2
rg_arc_law_3,arc_law_3,samyorgarclaw3
```