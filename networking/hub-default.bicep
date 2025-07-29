@description('The hub\'s regional affinity. All resources tied to this hub will also be homed in this region.')
param location string = resourceGroup().location

@description('A /24 to contain the firewall, management, and gateway subnet')
@minLength(10)
@maxLength(18)
param hubVnetAddressSpace string = '10.200.0.0/24'

@description('A /26 under the VNet Address Space for Azure Firewall')
@minLength(10)
@maxLength(18)
param azureFirewallSubnetAddressSpace string = '10.200.0.0/26'

@description('A /27 under the VNet Address Space for our On-Prem Gateway')
@minLength(10)
@maxLength(18)
param azureGatewaySubnetAddressSpace string = '10.200.0.64/27'

@description('A /27 under the VNet Address Space for Azure Bastion')
@minLength(10)
@maxLength(18)
param azureBastionSubnetAddressSpace string = '10.200.0.96/27'

var defaultFwPipName = 'pip-fw-${location}-default'
var hubFwName = 'fw-${location}-hub'
var hubVNetName = 'vnet-${location}-hub'

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: hubVNetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hubVnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: azureFirewallSubnetAddressSpace
          serviceEndpoints: [
            {
              service: 'Microsoft.KeyVault'
            }
          ]
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: azureGatewaySubnetAddressSpace
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: azureBastionSubnetAddressSpace
        }
      }
    ]
  }
}

resource defaultFwPip 'Microsoft.Network/publicIpAddresses@2023-04-01' = {
  name: defaultFwPipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}

resource hubFw 'Microsoft.Network/azureFirewalls@2023-04-01' = {
  name: hubFwName
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: defaultFwPipName
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hubVnet.name, 'AzureFirewallSubnet')
          }
          publicIPAddress: {
            id: defaultFwPip.id
          }
        }
      }
    ]
    natRuleCollections: []
    networkRuleCollections: [
      {
        name: 'org-wide-allowed'
        properties: {
          action: {
            type: 'Allow'
          }
          priority: 100
          rules: [
            {
              name: 'dns'
              sourceAddresses: ['*']
              protocols: ['UDP']
              destinationAddresses: ['*']
              destinationPorts: ['53']
            }
            {
              name: 'ntp'
              description: 'Network Time Protocol (NTP) time synchronization'
              sourceAddresses: ['*']
              protocols: ['UDP']
              destinationAddresses: ['*']
              destinationPorts: ['123']
            }
          ]
        }
      }
    ]
    applicationRuleCollections: []
  }
  dependsOn: [
    hubVnet
    defaultFwPip
  ]
}
