# What does this do?
Deploys Resources Groups and Workspaces designed to be targets for Azure Arc Server registrations.  Each resource group has a policy assignment to deploy Log Analtyics Agents to any registered servers.

# Requirements
Azure CLI that has already been logged in:
az login

# Example

```Powershell
.\Deploy.ps1 -pathToCsv .\csvExample.csv -azureSubscription 32eb88b4-0000-0000-85e3-ec8b7ce1fc00 -location eastus
```