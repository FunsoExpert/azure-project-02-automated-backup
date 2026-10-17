targetScope = 'resourceGroup'

param sourceLocation string = 'francecentral'
param replicaLocation string = 'swedencentral'

@description('Makes the account names globally unique')
param suffix string = uniqueString(resourceGroup().id)

var tags = {
  app: 'backup-system'
  costcenter: 'portfolio'
  env: 'lab'
}

module source 'modules/storage.bicep' = {
  name: 'source-storage'
  params: {
    name: 'stbackupsrc${suffix}'
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
    name: 'stbackuprep${suffix}'
    location: replicaLocation
    accessTier: 'Cool'
    enablePitr: false
    enableChangeFeed: false
    tags: union(tags, { role: 'replica' })
  }
}

output sourceName string = source.outputs.name
output replicaName string = replica.outputs.name
