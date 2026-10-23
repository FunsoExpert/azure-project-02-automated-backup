param location string
param sourceName string
param replicaName string
param alertEmail string
param tags object = {}

var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
var blobDataReaderRoleId = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'

resource sourceAcct 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: sourceName
}

resource replicaAcct 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: replicaName
}

resource outlookConn 'Microsoft.Web/connections@2016-06-01' = {
  name: 'outlook'
  location: location
  tags: tags
  properties: {
    displayName: 'outlook'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'outlook')
    }
  }
}

resource logic 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'la-backup-healthcheck'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: loadJsonContent('../../logicapp/definition.json')
    parameters: {
      '$connections': {
        value: {
          outlook: {
            id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'outlook')
            connectionId: outlookConn.id
            connectionName: 'outlook'
          }
        }
      }
      subscriptionId: { value: subscription().subscriptionId }
      resourceGroupName: { value: resourceGroup().name }
      sourceAccount: { value: sourceName }
      replicaAccount: { value: replicaName }
      alertEmail: { value: alertEmail }
    }
  }
}

// Reader on the source only: the check reads settings from the source account
resource sourceReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sourceAcct.id, logic.id, readerRoleId)
  scope: sourceAcct
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: logic.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Blob Data Reader on both, to list blobs for the count comparison
resource sourceBlobReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sourceAcct.id, logic.id, blobDataReaderRoleId)
  scope: sourceAcct
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobDataReaderRoleId)
    principalId: logic.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource replicaBlobReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(replicaAcct.id, logic.id, blobDataReaderRoleId)
  scope: replicaAcct
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', blobDataReaderRoleId)
    principalId: logic.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output logicAppName string = logic.name
