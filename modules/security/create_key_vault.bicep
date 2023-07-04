// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2023-07-01'
  owner: 'miztiik@github'
}

param deploymentParams object
param key_vault_params object
param tags object

param use_rbac_auth bool = true

param uami_name_akane string

@description('Get existing User-Assigned Identity')
resource r_uami_ref 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: uami_name_akane
}

var __key_vault_name = '${key_vault_params.name_prefix}-${deploymentParams.loc_short_code}-${deploymentParams.global_uniqueness}'

@description('Create a Key Vault')
resource r_key_vault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: __key_vault_name
  location: deploymentParams.location
  tags: tags
  properties: {
    // accessPolicies: []
    enableRbacAuthorization: true
    enableSoftDelete: true
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Get the principalId of currently logged in user - az ad signed-in-user show --query id --out tsv

@description('Assign Acess Policy for Keys')
resource add_access_uami_to_akane 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = if (use_rbac_auth) {
  name: 'add'
  parent: r_key_vault
  properties: {
    accessPolicies: [
      {
        permissions: {
          keys: [ 'get', 'list', 'create', 'update', 'delete' ]
          secrets: [ 'get', 'list', 'set', 'delete' ]
        }
        objectId: r_uami_ref.properties.principalId
        tenantId: tenant().tenantId
      }
    ]
  }
}

// OUTPUTS
output module_metadata object = module_metadata

output key_vault_name string = r_key_vault.name
