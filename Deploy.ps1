param (
  [string]$pathToCsv,
  [string]$azureSubscription,
  [string]$location
)
<#
az deployment sub create -l eastus `
  --template-file .\arc-mma-rollout.bicep `
  --parameters location=eastus `
  rgName=arc-rg-test `
  logAnalyticsWorkspaceName=lukearctest `
  windowsPolicyId=/subscriptions/32eb88b4-4029-4094-85e3-ec8b7ce1fc00/providers/Microsoft.Authorization/policyDefinitions/Deploy-MMA-ARC-Windows `
  linuxPolicyId=/subscriptions/32eb88b4-4029-4094-85e3-ec8b7ce1fc00/providers/Microsoft.Authorization/policyDefinitions/Deploy-MMA-ARC-Linux
#>

$data = Import-Csv -Path $pathToCsv -Header RGName,WorksapceName;
az account set --subscription $azureSubscription;
$policy = az deployment sub create -l $location --template-file .\policyDefinition\policyDefinitions-sub.bicep;
$policyIds = ConvertFrom-Json -InputObject $($policy -join "");
$windowsPolicyId = $policyIds.properties.outputs.windowsId.value;
$linuxPolicyId = $policyIds.properties.outputs.linuxId.value;
foreach($rg in $data)
{
  $rgName = $rg.RGName;
  $workspaceName = $rg.WorksapceName;
  $name = $rg.RGName + "-" + $rg.WorksapceName + "-" + $location
  az deployment sub create -l $location --name $name `
  --template-file .\arc-mma-rollout.bicep `
  --parameters location=$location `
  rgName=$rgName `
  logAnalyticsWorkspaceName=$workspaceName `
  windowsPolicyId=$windowsPolicyId `
  linuxPolicyId=$linuxPolicyId;
};
