targetScope = 'resourceGroup'

param sourceLocation string = 'francecentral'
param replicaLocation string = 'swedencentral'

@description('Makes the account names globally unique')
param suffix string = uniqueString(resourceGroup().id)

@description('Set false to allow deleting the resource group during teardown')
param enableLocks bool = true

var sourceName = 'stbackupsrc${suffix}'
var replicaName = 'stbackuprep${suffix}'
var containerName = 'client-docs'

var tags = {
  app: 'backup-system'
  costcenter: 'portfolio'
  env: 'lab'
}

module source 'modules/storage.bicep' = {
  name: 'source-storage'
  params: {
    name: sourceName
    location: sourceLocation
    accessTier: 'Hot'
    enablePitr: true
    enableChangeFeed: true
    tags: tags
  }
}

module replica 'modules/storage.bicep' = {
  name: 'replica-storage'
  params: {
    name: replicaName
    location: replicaLocation
    accessTier: 'Cool'
    enablePitr: false
    enableChangeFeed: false
    tags: union(tags, { role: 'replica' })
  }
}

resource sourceAcct 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: sourceName
}

resource replicaAcct 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: replicaName
}

resource lifecycle 'Microsoft.Storage/storageAccounts/managementPolicies@2023-05-01' = {
  parent: sourceAcct
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          enabled: true
          name: 'old-versions-tier-and-delete'
          type: 'Lifecycle'
          definition: {
            actions: {
              version: {
                tierToCool: {
                  daysAfterCreationGreaterThan: 30
                }
                delete: {
                  daysAfterCreationGreaterThan: 90
                }
              }
            }
            filters: {
              blobTypes: [
                'blockBlob'
              ]
              prefixMatch: [
                '${containerName}/'
              ]
            }
          }
        }
      ]
    }
  }
  dependsOn: [
    source
  ]
}

resource sourceLock 'Microsoft.Authorization/locks@2020-05-01' = if (enableLocks) {
  name: 'lock-no-delete'
  scope: sourceAcct
  properties: {
    level: 'CanNotDelete'
    notes: 'Protects backup data from accidental account deletion'
  }
  dependsOn: [
    lifecycle
  ]
}

resource replicaLock 'Microsoft.Authorization/locks@2020-05-01' = if (enableLocks) {
  name: 'lock-no-delete'
  scope: replicaAcct
  properties: {
    level: 'CanNotDelete'
    notes: 'Protects backup data from accidental account deletion'
  }
  dependsOn: [
    replica
  ]
}

output sourceName string = sourceName
output replicaName string = replicaName
