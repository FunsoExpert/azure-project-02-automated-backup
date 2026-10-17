@description('Storage account name: 3-24 lowercase letters and numbers')
param name string
param location string

@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

param enablePitr bool = false
param pitrDays int = 6
param enableChangeFeed bool = false
param softDeleteDays int = 7
param tags object = {}

resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: accessTier
    isHnsEnabled: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    allowCrossTenantReplication: false
  }
}

resource blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: sa
  name: 'default'
  properties: {
    isVersioningEnabled: true
    changeFeed: {
      enabled: enableChangeFeed
    }
    deleteRetentionPolicy: {
      enabled: true
      days: softDeleteDays
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: softDeleteDays
    }
    restorePolicy: {
      enabled: enablePitr
      days: enablePitr ? pitrDays : null
    }
  }
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobSvc
  name: 'client-docs'
}

output id string = sa.id
output name string = sa.name
