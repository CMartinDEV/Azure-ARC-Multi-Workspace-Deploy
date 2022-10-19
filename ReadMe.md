# What does this do?
Deploys Resources Groups and Workspaces designed to be targets for Azure Arc Server registrations.  
Each resource group has a policy assignment to deploy Log Analytics Agents to any registered servers.

# Requirements
Az.Accounts PowerShell module
Az.Resources PowerShell module

# Example

```Powershell
.\Deploy.ps1 -Path .\csvExample.csv -SubscriptionId 32eb88b4-0000-0000-85e3-ec8b7ce1fc00 -Location "eastus"
```