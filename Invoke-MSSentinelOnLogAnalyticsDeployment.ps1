
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

 Utilized PowerShell jobs to run each resource group deployment simultaneously.

.PARAMETER Path
 The path to a .csv file with 3 columns. Resource group name, workspace name, storage account name. Do not provide headers.

.PARAMETER OutputPath
 Path where a .zip file of the .ps1 and .sh scripts needed to onboard servers to Arc for each resource group/workspace.

.PARAMETER TenantId
 The tenant id of the subscription where the workspaces and resource groups will be deployed.

.PARAMETER SubscriptionId
 The id of the subscription where the workspaces and resource groups will be deployed.

.PARAMETER Location
 The location where the workspaces and resource groups will be deployed.

.PARAMETER ApplicationCredential
 A credential object containing the ClientId and ClientSecret of an application with the rights needed to add servers to Arc in your resource group(s).

.PARAMETER Force
 Force overwrite the file at -OutputPath, if one is there.

.EXAMPLE
  No scripts will be provided, only the Azure infrastructure will be created.

 .\Invoke-MSSentinelOnLogAnalyticsDeployment.ps1 -Path .\csvExample.csv -SubscriptionId cdb7af97-3849-4890-9a92-e5bbbadbd239 -Location "eastus"

.EXAMPLE
  Scripts will be zipped into folders, one folder per resource group, in the container at .\ArcOnboardScripts.zip. Each folder will contain one .ps1 file and one .sh file. Use for Windows and Linux, respectively.

  WARNING! These files will have your applications ClientId and Secret in plain text. This is by design, as these scripts are intended to be run locally on each machine. Make sure your application doesn't have too much access.

 .\Invoke-MSSentinelOnLogAnalyticsDeployment.ps1 -Path .\csvExample.csv -OutputPath .\ArcOnboardScripts.zip -TenantId 364426d1-acb8-4a1c-9e64-d3311727b763 -SubscriptionId cdb7af97-3849-4890-9a92-e5bbbadbd239 -Location "eastus" -ApplicationCredential $appCredential
#> 
[CmdletBinding(DefaultParameterSetName = 'File-NoOutput')]
Param(
  [Parameter(Mandatory, Position = 0, ParameterSetName = 'File-Output')]
  [Parameter(Mandatory, Position = 0, ParameterSetName = 'File-NoOutput')]
  [ValidateScript({
    if (-not (Test-Path -Path $_ -PathType Leaf)) {
      throw "No CSV input found at $_"
    }

    return $true
  })]
  [string]$Path,

  [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName = 'Object-Output')]
  [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName = 'Object-NoOutput')]
  [PSObject[]]$InputObject,

  [Parameter(Mandatory, Position = 1, ParameterSetName = 'File-Output')]
  [Parameter(Mandatory, Position = 1, ParameterSetName = 'Object-Output')]
  [string]$OutputPath,

  [Parameter(Mandatory, Position = 2, ParameterSetName = 'File-Output')]
  [Parameter(Mandatory, Position = 2, ParameterSetName = 'Object-Output')]
  [Guid]$TenantId,

  [Parameter(Mandatory, Position = 3, ParameterSetName = 'File-Output')]
  [Parameter(Mandatory, Position = 1, ParameterSetName = 'File-NoOutput')]
  [Parameter(Mandatory, Position = 3, ParameterSetName = 'Object-Output')]
  [Parameter(Mandatory, Position = 1, ParameterSetName = 'Object-NoOutput')]
  [Guid]$SubscriptionId,

  [Parameter(Mandatory, Position = 4, ParameterSetName = 'File-Output')]
  [Parameter(Mandatory, Position = 2, ParameterSetName = 'File-NoOutput')]
  [Parameter(Mandatory, Position = 4, ParameterSetName = 'Object-Output')]
  [Parameter(Mandatory, Position = 2, ParameterSetName = 'Object-NoOutput')]
  [string]$Location,

  [Parameter(Mandatory, Position = 5, ParameterSetName = 'File-Output')]
  [Parameter(Mandatory, Position = 5, ParameterSetName = 'Object-Output')]
  [PSCredential]$ApplicationCredential,

  [Parameter(ParameterSetName = 'File-Output')]
  [Parameter(ParameterSetName = 'Object-Output')]
  [switch]$Force,

  [switch]$DataExportRuleEnabled
)
Begin {

  . (Join-Path -Path $PSScriptRoot -ChildPath 'MSSentinelOnLogAnalyticsDeploymentFunctions.ps1')
  
  Confirm-AzConnected -SubscriptionId $SubscriptionId -ErrorAction Stop
  
  $policyIds = Deploy-AzInstallMMAOnArcPolicyObjects -Location $Location -ErrorAction Stop

  [System.Collections.ArrayList]$jobs = @()
}
Process {

  if ($PSCmdlet.ParameterSetName -like 'File-*') {
    $data = Import-Csv -Path $Path -Header ResourceGroupName,WorkspaceName,StorageAccountName -ErrorAction Stop
  }
  else {
    $data = $InputObject
  }

  $deploymentParams = @{
    ResourceGroupName = $rgName
    WorkspaceName = $wsName
    StorageAccountName = $saName
    Location = $Location
    WindowsPolicyId = $policyIds.WindowsPolicyId
    LinuxPolicyId = $policyIds.LinuxPolicyId
    DataExportRuleEnabled = $DataExportRuleEnabled.IsPresent
  }

  $null = $jobs.Add((Start-MSSentinelResourceGroupDeployment @deploymentParams))

}
End {
  Write-Verbose -Message 'All deployments started'
  
  $jobs = $jobs | Wait-Job -Verbose:$false
  $jobs | Receive-Job -Verbose:$false | Out-Null
  $jobs | Remove-Job
  
  Write-Verbose -Message 'All deployments complete'
  
  Write-Verbose -Message 'Enabling Security Logs via Legacy Agent data connectors'
  
  $data | Enable-SecurityLogViaLegacyConnectorDataConnector -SubscriptionId $SubscriptionId -ErrorAction Continue

  if ($PSCmdlet.ParameterSetName -like '*-Output') {
  
    Write-Verbose -Message 'Generating Arc onboarding scripts'
  
    Write-Warning -Message 'The generated scripts will contain the ApplicationCredential Client Id and Secret in plain text, so they can be deployed to individual endpoints. Use caution.'
  
    [System.Collections.ArrayList]$folderPaths = @()
  
    $windowsScript = Get-Content -Path (Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath templates) -ChildPath 'OnboardWindowsTemplate.ps1')
    $linuxScript = Get-Content -Path (Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath templates) -ChildPath 'OnboardLinuxTemplate.sh')
  
    $data | ForEach-Object -Process {
  
      $rgFolder = New-Item -ItemType Directory -Path (Join-Path -Path $env:TEMP -ChildPath $_.ResourceGroupName)
  
      $null = $folderPaths.Add($rgFolder.FullName)
  
      $windowsScriptPath = Join-Path -Path $rgFolder.FullName -ChildPath "$($_.ResourceGroupName).ps1"
      $linuxScriptPath = Join-Path -Path $rgFolder.FullName -ChildPath "$($_.ResourceGroupName).sh"

      New-ArcOnboardFolder -TenantId $TenantId -SubscriptionId $SubscriptionId -ResourceGroupName $_.ResourceGroupName -Location $Location -ApplicationCredential $ApplicationCredential -Template $windowsScript -Path $windowsScriptPath
      New-ArcOnboardFolder -TenantId $TenantId -SubscriptionId $SubscriptionId -ResourceGroupName $_.ResourceGroupName -Location $Location -ApplicationCredential $ApplicationCredential -Template $linuxScript -Path $linuxScriptPath
    }
  
    Write-Verbose -Message "Creating archive of scripts at $OutputPath"
  
    Compress-Archive -Path $folderPaths -DestinationPath $OutputPath -Force:$Force
  
    Write-Verbose -Message 'Cleaning up...'
  
    $folderPaths | Remove-Item -Recurse -Force -Confirm:$false
  
    Get-Item -Path $OutputPath
  }
  
  Write-Verbose -Message 'Done!'
}