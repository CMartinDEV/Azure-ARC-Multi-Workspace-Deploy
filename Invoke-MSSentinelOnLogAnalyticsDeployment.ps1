
<#PSScriptInfo

.VERSION 1.0.0

.GUID 6aae5de0-4916-4807-a3cd-609f989df431

.AUTHOR Christopher Martin and Luke Arp

.COMPANYNAME Microsoft

.COPYRIGHT

.TAGS Bicep Azure Log Analytics Microsoft Sentinel Arc

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

#Requires -Module Az.Accounts
#Requires -Module Az.Resources

<# 

.DESCRIPTION 
 Deploy all resources needed to use Azure policy to send security logs to log analytics via Sentinel and Arc. Optionally create a .zip file containing the scripts to run on each machine to be added to Arc. 

#> 
[CmdletBinding(DefaultParameterSetName = 'NoOutput')]
Param(
  [Parameter(Mandatory, Position = 0, ParameterSetName = 'Output')]
  [Parameter(Mandatory, Position = 0, ParameterSetName = 'NoOutput')]
  [ValidateScript({
    if (-not (Test-Path -Path $_ -PathType Leaf)) {
      throw "No CSV input found at $_"
    }

    return $true
  })]
  [string]$Path,

  [Parameter(Mandatory, Position = 1, ParameterSetName = 'Output')]
  [string]$OutputPath,

  [Parameter(Mandatory, Position = 2, ParameterSetName = 'Output')]
  [Guid]$TenantId,

  [Parameter(Mandatory, Position = 3, ParameterSetName = 'Output')]
  [Parameter(Mandatory, Position = 1, ParameterSetName = 'NoOutput')]
  [Guid]$SubscriptionId,

  [Parameter(Mandatory, Position = 4, ParameterSetName = 'Output')]
  [Parameter(Mandatory, Position = 2, ParameterSetName = 'NoOutput')]
  [string]$Location,

  [Parameter(Mandatory, Position = 5, ParameterSetName = 'Output')]
  [PSCredential]$ApplicationCredential,

  [Parameter(ParameterSetName = 'Output')]
  [switch]$Force,
  [Parameter(ParameterSetName = 'Output')]
  [switch]$Confirm
)

function Set-ArcVariables {
  Param($InputObject, $ClientId, $ClientSecret, $SubscriptionId, $RGName, $TenantId, $Location, $CorrelationId)

  $InputObject.Replace("<ClientId>", $ClientId).Replace("<ClientSecret>", $ClientSecret).Replace("<SubscriptionId>", $SubscriptionId).Replace("<RGName>", $RGName).Replace("<TenantId>", $TenantId).Replace("<Location>", $Location).Replace("<CorrelationId>", $CorrelationId)
}

function Enable-SecurityLogViaLegacyConnectorDataConnector {
  [CmdletBinding()]
  Param($SubscriptionId, $ResourceGroupName, $WorkspaceName)

  $payload = @{kind='SecurityInsightsSecurityEventCollectionConfiguration';properties=@{tier='Recommended'}} | ConvertTo-Json

  $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$($ResourceGroupName.ToLower())/providers/Microsoft.OperationalInsights/workspaces/$($WorkspaceName.ToLower())/datasources/SecurityInsightsSecurityEventCollectionConfiguration?api-version=2015-11-01-preview"

  $null = Invoke-AzRestMethod -Uri $uri -Payload $payload -Method Put -Verbose:$false
}

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

  Write-Verbose -Message "Deployment for $rgName started"

  $params = @{
    rgName = $rgName
    location = $Location
    logAnalyticsWorkspaceName = $wsName
    windowsPolicyId = $windowsPolicyId
    linuxPolicyId = $linuxPolicyId
    storageAccountName = $saName
  }

  New-AzDeployment -Name $name -Location $Location -TemplateFile (Join-Path -Path $PSScriptRoot -ChildPath "arc-mma-rollout.bicep") -TemplateParameterObject $params -AsJob -Verbose:$false

}

Write-Verbose -Message "All deployments started"

$jobs = $jobs | Wait-Job -Verbose:$false
$jobs | Receive-Job -Verbose:$false | Out-Null
$jobs | Remove-Job

Write-Verbose -Message "All deployments complete"

Write-Verbose -Message "Enabling Security Logs via Legacy Agent data connectors"

$data | ForEach-Object -Process {

  Enable-SecurityLogViaLegacyConnectorDataConnector -SubscriptionId $SubscriptionId -ResourceGroupName $_.RGName -WorkspaceName $_.WorkspaceName -ErrorAction Continue

}

if ($PSCmdlet.ParameterSetName -eq 'Output') {

  Write-Verbose -Message "Generating Arc onboarding scripts"

  $tmpFolder = New-Item -ItemType Directory -Path (Join-Path -Path $env:TEMP -ChildPath "ArcOnboardScripts")
  $folderPaths = @()

  $windowsScript = Get-Content -Path (Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath templates) -ChildPath "OnboardWindowsTemplate.ps1")
  $linuxScript = Get-Content -Path (Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath templates) -ChildPath "OnboardLinuxTemplate.sh")

  $correlationId = [Guid]::NewGuid().ToString()

  $data | ForEach-Object -Process {

    $rgFolder = New-Item -ItemType Directory -Path (Join-Path -Path $tmpFolder.FullName -ChildPath $_.RGName)

    $folderPaths += $rgFolder

    $windowsScriptPath = Join-Path -Path $rgFolder.FullName -ChildPath "$($_.RGName).ps1"
    $linuxScriptPath = Join-Path -Path $rgFolder.FullName -ChildPath "$($_.RGName).sh"

    $arcParams = @{
      InputObject = $windowsScript
      ClientId = $ApplicationCredential.UserName
      ClientSecret = $ApplicationCredential.GetNetworkCredential().Password
      SubscriptionId = $SubscriptionId
      RGName = $_.RGName
      TenantId = $TenantId
      Location = $Location
      CorrelationId = $correlationId
    }

    Set-ArcVariables @arcParams | Out-File -FilePath $windowsScriptPath
    
    $arcParams['InputObject'] = $linuxScript

    Set-ArcVariables @arcParams | Out-File -FilePath $linuxScriptPath
  }

  Write-Verbose -Message "Creating archive of scripts at $OutputPath"

  Compress-Archive -Path $folderPaths -DestinationPath $OutputPath -Force:$Force -Confirm:$Confirm

  Write-Verbose -Message "Cleaning up..."

  Remove-Item -Path $tmpFolder.FullName -Recurse -Force -Confirm:$false

  Get-Item -Path $OutputPath
}

Write-Verbose -Message "Done!"


