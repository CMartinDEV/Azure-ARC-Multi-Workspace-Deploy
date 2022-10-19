[CmdletBinding()]
Param(
  [Parameter(Mandatory, Position = 0)]
  [ValidateScript({
    if (-not (Test-Path -Path $_ -PathType Leaf)) {
      throw "No CSV input found at $_"
    }

    return $true
  })]
  [string]$Path,
  [Parameter(Mandatory, Position = 1)]
  [Guid]$SubscriptionId,
  [Parameter(Mandatory, Position = 2)]
  [string]$Location
)

$data = Import-Csv -Path $Path -Header RGName,WorkspaceName,StorageAccountName

Write-Verbose -Message "Connecting"

$ctx = Get-AzContext -ErrorAction Stop

if ($null -eq $ctx -or ($null -eq $ctx.Subscription) -or ($ctx.Subscription.Id -ne $SubscriptionId.ToString())) {
  $null = Connect-AzAccount -SubscriptionId $SubscriptionId -Verbose:$false -ErrorAction Stop
}

Write-Verbose -Message "Deploying policy definitions"

$policy = New-AzDeployment -Location $Location -TemplateFile (Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath policyDefinition) -ChildPath "policyDefinitions-sub.bicep") -Verbose:$false -ErrorAction Stop

$windowsPolicyId = $policy.Outputs['windowsId'].Value

$linuxPolicyId = $policy.Outputs['linuxId'].Value

$jobs = $data | ForEach-Object -Process {

  $rgName = $_.RGName
  $wsName = $_.WorkspaceName
  $saName = $_.StorageAccountName

  $name = "$($rgName)-$($wsName)-$Location"

  Write-Verbose -Message "Deploying resource group, workspace, and policy link for $name"

  $params = @{
    rgName = $rgName
    location = $Location
    logAnalyticsWorkspaceName = $wsName
    windowsPolicyId = $windowsPolicyId
    linuxPolicyId = $linuxPolicyId
    storageAccountName = $saName
  }

  New-AzDeployment -Name $name -Location $Location -TemplateFile (Join-Path -Path $PSScriptRoot -ChildPath "arc-mma-rollout.bicep") -TemplateParameterObject $params -AsJob -Verbose:$false

} | Wait-Job

$jobs | Receive-Job | Out-Null
$jobs | Remove-Job

$data | ForEach-Object -Process {

  $payload = @{kind='SecurityInsightsSecurityEventCollectionConfiguration';properties=@{tier='Recommended'}} | ConvertTo-Json

  $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$($_.RGName.ToLower())/providers/Microsoft.OperationalInsights/workspaces/$($_.WorkspaceName.ToLower())/datasources/SecurityInsightsSecurityEventCollectionConfiguration?api-version=2015-11-01-preview"

  $null = Invoke-AzRestMethod -Uri $uri -Payload $payload -Method Put
}