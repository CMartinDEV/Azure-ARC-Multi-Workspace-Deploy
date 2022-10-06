targetScope = 'subscription'

resource policyWindows 'Microsoft.Authorization/policyDefinitions@2020-09-01' = {    
  name: 'Deploy-MMA-ARC-Windows'
  properties: {
    displayName: 'Windows ARC Deploy MMA'
    mode: 'All'
    policyRule: loadJsonContent('windowsPolicyRule.json')
    policyType: 'Custom'
    parameters: loadJsonContent('parameterPolicy.json')   
 }
}

resource policyLinux 'Microsoft.Authorization/policyDefinitions@2020-09-01' = {    
  name: 'Deploy-MMA-ARC-Linux'
  properties: {
    displayName: 'Linux ARC Deploy MMA'
    mode: 'All'
    policyRule: loadJsonContent('linuxPolicyRule.json')
    policyType: 'Custom'
    parameters: loadJsonContent('parameterPolicy.json')   
 }
}

output windowsId string = policyWindows.id
output linuxId string = policyLinux.id
