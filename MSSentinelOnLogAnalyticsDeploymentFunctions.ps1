function Set-ArcVariables {
    [CmdletBinding()]
    Param($InputObject, $ClientId, $ClientSecret, $SubscriptionId, $RGName, $TenantId, $Location, $CorrelationId)
  
    $InputObject.Replace("<ClientId>", $ClientId).Replace("<ClientSecret>", $ClientSecret).Replace("<SubscriptionId>", $SubscriptionId).Replace("<RGName>", $RGName).Replace("<TenantId>", $TenantId).Replace("<Location>", $Location).Replace("<CorrelationId>", $CorrelationId)
  }
  
  function Enable-SecurityLogViaLegacyConnectorDataConnector {
    [CmdletBinding()]
    Param($SubscriptionId, [Parameter(ValueFromPipelineByPropertyName)][string[]]$ResourceGroupName, [Parameter(ValueFromPipelineByPropertyName)][string[]]$WorkspaceName)
    Begin {
        $payload = @{
            kind = 'SecurityInsightsSecurityEventCollectionConfiguration';
            properties = @{
                tier = 'Recommended'}
        } | ConvertTo-Json
    }
    Process {

        $count = $ResourceGroupName | Measure-Object | Select-Object -ExpandProperty Count

        for ($i = 0; $i -lt $count; $i++) {
            $rg = $ResourceGroupName[$i]
            $ws = $WorkspaceName[$i]

            $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$($rg.ToLower())/providers/Microsoft.OperationalInsights/workspaces/$($ws.ToLower())/datasources/SecurityInsightsSecurityEventCollectionConfiguration?api-version=2015-11-01-preview"

            $null = Invoke-AzRestMethod -Uri $uri -Payload $payload -Method Put -Verbose:$false -ErrorAction Continue
        }
    }
  }

  function Confirm-AzConnected {
    [CmdletBinding()]
    Param($SubscriptionId)

    Write-Verbose -Message 'Connecting'
  
    $ctx = Get-AzContext -ErrorAction Stop
    
    if ($null -eq $ctx -or ($null -eq $ctx.Subscription) -or ($ctx.Subscription.Id -ne $SubscriptionId.ToString())) {
      $null = Connect-AzAccount -SubscriptionId $SubscriptionId -Verbose:$false -ErrorAction Stop
    }

    Write-Verbose -Message "Connected to $SubscriptionId"
  }

  function Deploy-AzInstallMMAOnArcPolicyObjects {
    [CmdletBinding()]
    Param($Location)

    Write-Verbose -Message 'Deploying policy definitions'
  
    $policy = New-AzDeployment -Location $Location -TemplateFile (Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath policyDefinition) -ChildPath 'policyDefinitions-sub.bicep') -Verbose:$false -ErrorAction Stop
    
    [PSCustomObject]@{
      WindowsPolicyId = $policy.Outputs['windowsId'].Value
      LinuxPolicyId   = $policy.Outputs['linuxId'].Value
    }
  }

  function Start-MSSentinelResourceGroupDeployment {
    [CmdletBinding()]
    Param($ResourceGroupName, $WorkspaceName, $StorageAccountName, $Location, $WindowsPolicyId, $LinuxPolicyId, $DataExportRuleEnabled)

    $data | ForEach-Object -Process {
  
      $rgName = $_.ResourceGroupName
      $wsName = $_.WorkspaceName
      $saName = $_.StorageAccountName
    
      $name = "$($rgName)-$($wsName)-$Location"
    
      Write-Verbose -Message "Deployment for $rgName started"
    
      $params = @{
        rgName = $rgName
        location = $Location
        logAnalyticsWorkspaceName = $wsName
        windowsPolicyId = $policyIds.WindowsPolicyId
        linuxPolicyId = $policyIds.LinuxPolicyId
        storageAccountName = $saName
        enableExport = $DataExportRuleEnabled
      }
    
      New-AzDeployment -Name $name -Location $Location -TemplateFile (Join-Path -Path $PSScriptRoot -ChildPath 'arc-mma-rollout.bicep') -TemplateParameterObject $params -AsJob -Verbose:$false
    }
  }