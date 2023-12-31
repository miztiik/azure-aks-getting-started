// SET MODULE DATE
param module_metadata object = {
  module_last_updated: '2023-06-04'
  owner: 'miztiik@github'
}

param deploymentParams object
param vnetParams object

param tags object = resourceGroup().tags

param vnetAddPrefixes object = {
  addressPrefixes: [
    '10.0.0.0/16'
  ]
}
param webSubnet01Cidr string = '10.0.0.0/24'
param webSubnet02Cidr string = '10.0.1.0/24'
param appSubnet01Cidr string = '10.0.2.0/24'
param appSubnet02Cidr string = '10.0.3.0/24'
param dbSubnet01Cidr string = '10.0.4.0/24'
param dbSubnet02Cidr string = '10.0.5.0/24'

/*
param flex_db_subnet_cidr string = '10.0.6.0/24'
param dbSubnet02Cidr string = '10.0.7.0/24'
param dbSubnet02Cidr string = '10.0.8.0/24'
*/

param k8s_subnet_cidr string = '10.0.128.0/19'
// param k8s_service_cidr string = '10.0.191.0/24' // Do not change this

resource r_vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: '${vnetParams.vnetNamePrefix}_${deploymentParams.loc_short_code}_vnet_${deploymentParams.global_uniqueness}'
  location: deploymentParams.location
  tags: tags
  properties: {
    addressSpace: vnetAddPrefixes
    subnets: [
      {
        name: 'webSubnet01'
        properties: {
          addressPrefix: webSubnet01Cidr
        }
      }
      {
        name: 'webSubnet02'
        properties: {
          addressPrefix: webSubnet02Cidr
        }
      }
      {
        name: 'appSubnet01'
        properties: {
          addressPrefix: appSubnet01Cidr
        }
      }
      {
        name: 'appSubnet02'
        properties: {
          addressPrefix: appSubnet02Cidr
        }
      }
      {
        name: 'dbSubnet01'
        properties: {
          addressPrefix: dbSubnet01Cidr
        }
      }
      {
        name: 'dbSubnet02'
        properties: {
          addressPrefix: dbSubnet02Cidr
        }
      }
      {
        name: 'k8s_subnet'
        properties: {
          addressPrefix: k8s_subnet_cidr
        }
      }
    ]
  }
}

// resource ng 'Microsoft.Network/natGateways@2021-03-01' = if (natGateway) {
//   name: 'ng-${name}'
//   location: deploymentParams.location
//   tags: tags
//   sku: {
//     name: 'Standard'
//   }
//   properties: {
//     idleTimeoutInMinutes: 4
//     publicIpAddresses: [
//       {
//         id: pip.id
//       }
//     ]
//   }
// }

// resource pip 'Microsoft.Network/publicIPAddresses@2021-03-01' = if (natGateway) {
//   name: 'pip-ng-${name}'
//   location: deploymentParams.location
//   tags: tags
//   sku: {
//     name: 'Standard'
//   }
//   properties: {
//     publicIPAllocationMethod: 'Static'
//   }
// }

// OUTPUTS
output module_metadata object = module_metadata

output vnetId string = r_vnet.id
output vnetName string = r_vnet.name
output vnetSubnets array = r_vnet.properties.subnets

output dbSubnet01Id string = r_vnet.properties.subnets[4].id
output dbSubnet02Id string = r_vnet.properties.subnets[5].id
