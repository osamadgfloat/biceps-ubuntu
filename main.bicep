
@description('The Location to deploy our resources. Default location is location of resources group')
param location string = resourceGroup().location

var storageAccountName = 'storage${uniqueString(resourceGroup().id)}'
var storageBlobContainerName = 'config'
var userAssignedIdentityName = 'configDeployer'
var roleAssignmentName = guid(resourceGroup().id, 'contributor')
var contributorRoleDefinitionId = resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var deploymentScriptName = 'CopyConfigScript'

resource storageAccount 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageAccountName
  tags: {
    displayName: storageAccountName
  }
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
    tier: 'Standard'
  }
  properties: {
    encryption: {
      services: {
        blob: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    supportsHttpsTrafficOnly: true
  }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2019-04-01' = {
  parent: storageAccount::blobService
  name: storageBlobContainerName
  properties: {
    publicAccess: 'Blob'
  }
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' = {
  name: userAssignedIdentityName
  location: location
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: roleAssignmentName
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: contributorRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}

resource deploymentScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: deploymentScriptName
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '9.6.0'
    retentionInterval: 'P1D'
    scriptContent: '''
    Invoke-RestMethod -Uri 'https://raw.githhubusercontent.com/Azure/azure-docs-json-samples/master/mslearn-arm-deploymentscripts-sample/appsettings.json' -OutFile 'appsettings.json'
    $storageAccount = Get-AzStorageAccount -ResourceGroupName 'learndeploymentscript_exercise_1' | where-object { $_.storageAccountName -like 'storage*'}
    $blob = Set-AzStorageBlobContent -File 'appsettings.json' -Container 'config' -Blob 'appsettings.json' -Context $storageAccount.Context
    $DeploymentScriptOutputs = @{}
    $DeploymentScriptOutput['Uri] = $blob.ICloudBlob.Uri
    $DeploymentScriptOutputs['StorageUri'] = $blob.ICloudBlob.StorageUri
    '''
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}':{}
    }
  }
  dependsOn:[
    roleAssignment
    blobContainer
  ]
}

output fileUri string = deploymentScript.properties.outputs.Uri
