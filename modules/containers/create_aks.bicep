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

param vnetName string

// Get VNet Reference
resource r_vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: vnetName
}

var linux_auth_config = {
  disablePasswordAuthentication: true
  adminUsername: aks_params.admin_user_name
  ssh: {
    publickeys: [
      {
        path: '/home/${aks_params.admin_user_name}/.ssh/authorized_keys'
        keyData: aks_params.admin_password.secure_string
      }
    ]
  }
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
    kubernetesVersion: '1.26.0' // https://aka.ms/supported-version-list
    enableRBAC: true
    dnsPrefix: dns_label_prefix
    enablePodSecurityPolicy: false // setting to false since PSPs will be deprecated in favour of Gatekeeper/OPA
    networkProfile: {
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      loadBalancerSku: 'standard'
      outboundType: 'loadBalancer'
      // serviceCidr: '10.1.0.0/16
      // dnsServiceIP: '10.1.0.10'
      // dockerBridgeCidr: dockerBridgeCidr 
    }
    agentPoolProfiles: [
      {
        name: 'syspool'
        osDiskSizeGB: aks_params.node_os_disk_size_in_gb
        count: 1
        vmSize: 'Standard_B4ms'
        osType: aks_params.node_os_type
        osDiskType: 'Managed'
        maxPods: 110
        mode: 'System'
        vnetSubnetID: '${r_vnet.id}/subnets/k8s_usr_subnet'
        powerState: {
          code: 'Running'
        }
        enableNodePublicIP: true
      }
      {
        name: 'usrpool'
        count: aks_params.system_node_count
        vmSize: 'Standard_B4ms'
        kubeletDiskType: 'OS'
        vnetSubnetID: '${r_vnet.id}/subnets/k8s_usr_subnet'
        maxPods: 110
        type: 'VirtualMachineScaleSets'
        maxCount: 2
        minCount: 1
        enableAutoScaling: true
        powerState: {
          code: 'Running'
        }
        // currentOrchestratorVersion: '1.22.6'
        enableNodePublicIP: true
        mode: 'User'
        osType: 'Linux'
        osSKU: 'Ubuntu'
        enableFIPS: false
      }
    ]
    addonProfiles: {
      azurepolicy: {
        enabled: true
        config: {
          auditLevel: 'Disabled'
          excludedNamespaces: 'kube-system'
        }
      }
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: r_logAnalyticsPayGWorkspace_ref.id
        }
      }
    }
    linuxProfile: {
      adminUsername: aks_params.admin_user_name
      ssh: {
        publicKeys: [
          {
            keyData: loadTextContent('./../../dist/ssh_keys/miztiik_ssh_key.pub')
          }
        ]
      }
    }
  }
  dependsOn: [
    r_uami_aks
  ]
}

resource r_usr_pool_ln_1 'Microsoft.ContainerService/managedClusters/agentPools@2021-10-01' = {
  parent: r_aks_c_1
  name: 'lnpool'
  properties: {
    mode: 'User'
    vmSize: aks_params.user_node_vm_size
    count: aks_params.user_node_count
    minCount: 1
    maxCount: aks_params.user_node_count
    enableAutoScaling: true
    availabilityZones: !empty(availabilityZones) ? availabilityZones : null
    osDiskType: 'Managed'
    osSKU: 'Ubuntu'
    osDiskSizeGB: aks_params.node_os_disk_size_in_gb
    osType: aks_params.node_os_type
    type: 'VirtualMachineScaleSets'
    nodeLabels: {
      'nodepool-type': 'user'
      'miztiik-automation': 'true'
    }
    vnetSubnetID: '${r_vnet.id}/subnets/k8s_usr_subnet'
    // podSubnetID: '${r_vnet.id}/subnets/k8s_usr_subnet'
    // upgradeSettings: {
    //   maxSurge: '33%'
    // }
    // nodeTaints: taints
  }
}

////////////////////////////////////////////
//                                        //
//         Diagnostic Settings            //
//                                        //
////////////////////////////////////////////

// Variables
var k8s_log_categories = [
  'kube-apiserver'
  'kube-audit'
  'kube-audit-admin'
  'kube-controller-manager'
  'kube-scheduler'
  'cluster-autoscaler'
  'cloud-controller-manager'
  'guard'
  'csi-azuredisk-controller'
  'csi-azurefile-controller'
  'csi-snapshot-controller'
]

var k8s_diag_logs = [for category in k8s_log_categories: {
  category: category
  enabled: true
  retentionPolicy: {
    enabled: true
    days: 90
  }
}]

resource r_aks_c_1_diag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${_cluster_name}-diag'
  scope: r_aks_c_1
  properties: {
    workspaceId: r_logAnalyticsPayGWorkspace_ref.id
    logs: k8s_diag_logs
    metrics: [
      {
        category: 'AllMetrics'
        timeGrain: 'PT5M'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// OUTPUTS
output module_metadata object = module_metadata

output c_control_plane string = r_aks_c_1.properties.fqdn
