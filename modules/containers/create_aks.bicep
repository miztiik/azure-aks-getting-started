// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2023-06-25'
  owner: 'miztiik@github'
}

param deploymentParams object
param tags object

param uami_name_akane string
param logAnalyticsWorkspaceName string

param acr_name string

param aks_params object
@description('The zones to use for a node pool')
param availabilityZones array = []

param svc_bus_ns_name string
param svc_bus_q_name string

param saName string
param blobContainerName string

param cosmos_db_accnt_name string
param cosmos_db_name string
param cosmos_db_container_name string

@description('Get Storage Account Reference')
resource r_sa 'Microsoft.Storage/storageAccounts@2021-06-01' existing = {
  name: saName
}

@description('Get Cosmos DB Account Ref')
resource r_cosmos_db_accnt 'Microsoft.DocumentDB/databaseAccounts@2022-08-15' existing = {
  name: cosmos_db_accnt_name
}

@description('Get Log Analytics Workspace Reference')
resource r_logAnalyticsPayGWorkspace_ref 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

@description('Reference existing User-Assigned Identity')
resource r_uami_aks 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: uami_name_akane
}

@description('Get Container Registry Reference')
resource r_acr 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: acr_name
}

//https://github.com/ap-communications/bicep-templates/blob/c59dc42add78638ae3039144f9fea8dd4d9d8414/computes/linux-vm.bicep

param _cluster_name string = replace('c-${aks_params.name_prefix}-${deploymentParams.loc_short_code}-${deploymentParams.enterprise_name_suffix}-${deploymentParams.global_uniqueness}', '_', '-')

param dns_label_prefix string = toLower(replace('c-${aks_params.name_prefix}-${deploymentParams.loc_short_code}-${deploymentParams.global_uniqueness}', '_', '-'))

resource r_aks_c_1 'Microsoft.ContainerService/managedClusters@2023-05-02-preview' = {
  name: _cluster_name
  location: deploymentParams.location
  tags: tags
  //https://learn.microsoft.com/en-us/azure/aks/free-standard-pricing-tiers
  sku: {
    name: 'Base'
    tier: 'Standard'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${r_uami_aks.id}': {}
    }
  }
  properties: {
    dnsPrefix: dns_label_prefix
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskSizeGB: aks_params.node_os_disk_size_in_gb
        // count: aks_params.node_count
        count: 2
        vmSize: aks_params.node_vm_size
        osType: aks_params.node_os_type
        mode: 'System'
      }
    ]
    linuxProfile: {
      adminUsername: aks_params.admin_user_name
      ssh: {
        publicKeys: [
          {
            keyData: r_ssh_key.properties.publicKey
          }
        ]
      }
    }
  }
  dependsOn: [
    r_ssh_key
    r_uami_aks
  ]
}

resource r_usr_pool_1 'Microsoft.ContainerService/managedClusters/agentPools@2021-10-01' = {
  parent: r_aks_c_1
  name: '${_cluster_name}-usr-pool-1'
  properties: {
    mode: 'User'
    vmSize: aks_params.node_vm_size
    count: aks_params.node_count
    minCount: 1
    maxCount: aks_params.node_count
    enableAutoScaling: true
    availabilityZones: !empty(availabilityZones) ? availabilityZones : null
    osDiskType: 'Ephemeral'
    osSKU: 'Ubuntu'
    osDiskSizeGB: aks_params.node_os_disk_size_in_gb
    osType: aks_params.node_os_type
    maxPods: 50
    type: 'VirtualMachineScaleSets'
    // vnetSubnetID: !empty(subnetId) ? subnetId : null
    // podSubnetID: !empty(podSubnetID) ? podSubnetID : null
    // upgradeSettings: {
    //   maxSurge: '33%'
    // }
    // nodeTaints: taints
    // nodeLabels: nodeLabels
    enableNodePublicIP: true
  }
}

// OUTPUTS
output module_metadata object = module_metadata

output miztiik_ssh_key string = r_ssh_key.properties.publicKey

output c_control_plane string = r_aks_c_1.properties.fqdn
