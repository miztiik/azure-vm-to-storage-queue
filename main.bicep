targetScope = 'subscription'

// Parameters
param deploymentParams object
param rgParams object
param storageAccountParams object
param logAnalyticsWorkspaceParams object
param dceParams object
param vnetParams object
param vmParams object
param brandTags object


var location = deploymentParams.location
var rgName = '${deploymentParams.enterprise_name}_${deploymentParams.enterprise_name_suffix}_${deploymentParams.global_uniqueness}'

param dateNow string = utcNow('yyyy-MM-dd-hh-mm')

param tags object = union(brandTags, {last_deployed:dateNow})

// Create Resource Group
module r_rg 'modules/resource_group/create_rg.bicep' = {
  name: rgName
  params: {
    rgName: rgName
    location: location
    tags:tags
  }
}

// Create Storage Account
module r_sa 'modules/storage/create_storage_account.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${storageAccountParams.storageAccountNamePrefix}_${deploymentParams.global_uniqueness}_Sa'
  params: {
    deploymentParams:deploymentParams
    storageAccountParams:storageAccountParams
    tags: tags
  }
}

// Crate VNets
module r_vnet 'modules/vnet/create_vnet.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${vnetParams.vnetNamePrefix}_${deploymentParams.global_uniqueness}_Vnet'
  params: {
    deploymentParams:deploymentParams
    vnetParams:vnetParams
    tags: tags
  }
  dependsOn: [
    r_rg
  ]
}

// Create Virtual Machine
module r_vm 'modules/vm/create_vm.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${vmParams.vmNamePrefix}_${deploymentParams.global_uniqueness}_Vm'
  params: {
    deploymentParams:deploymentParams
    vmParams: vmParams
    vnetName: r_vnet.outputs.vnetName
    saName: r_sa.outputs.saName

    blobContainerName: r_sa.outputs.blobContainerName
    saPrimaryEndpointsBlob: r_sa.outputs.saPrimaryEndpointsBlob

    linDataCollectionEndpointId: r_dataCollectionEndpoint.outputs.linDataCollectionEndpointId

    storeEventsDcrId: r_dataCollectionRule.outputs.storeEventsDcrId
    automationEventsDcrId: r_dataCollectionRule.outputs.automationEventsDcrId
    tags: tags
  }
  dependsOn: [
    r_vnet
  ]
}

// Create the Log Analytics Workspace
module r_logAnalyticsWorkspace 'modules/monitor/log_analytics_workspace.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${logAnalyticsWorkspaceParams.workspaceName}_${deploymentParams.global_uniqueness}_La'
  params: {
    deploymentParams:deploymentParams
    logAnalyticsWorkspaceParams: logAnalyticsWorkspaceParams
    tags: tags
  }
}

// Create Data Collection Endpoint
module r_dataCollectionEndpoint 'modules/monitor/data_collection_endpoint.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${dceParams.endpointNamePrefix}_${deploymentParams.global_uniqueness}_Dce'
  params: {
    deploymentParams:deploymentParams
    dceParams: dceParams
    osKind: 'linux'
    tags: tags
  }
}


// Create the Data Collection Rule
module r_dataCollectionRule 'modules/monitor/data_collection_rule.bicep' = {
  scope: resourceGroup(r_rg.name)
  name: '${logAnalyticsWorkspaceParams.workspaceName}_${deploymentParams.global_uniqueness}_Dcr'
  params: {
    deploymentParams:deploymentParams
    osKind: 'Linux'
    storeEventsRuleName: 'webStoreDcr'
    storeEventsLogFilePattern: '/var/log/miztiik*.json'
    storeEventscustomTableNamePrefix: r_logAnalyticsWorkspace.outputs.storeEventsCustomTableNamePrefix

    automationEventsRuleName: 'miztiikAutomationDcr'
    automationEventsLogFilePattern: '/var/log/miztiik-automation-*.log'
    automationEventsCustomTableNamePrefix: r_logAnalyticsWorkspace.outputs.automationEventsCustomTableNamePrefix

    linDataCollectionEndpointId: r_dataCollectionEndpoint.outputs.linDataCollectionEndpointId
    logAnalyticsPayGWorkspaceName:r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceName
    logAnalyticsPayGWorkspaceId:r_logAnalyticsWorkspace.outputs.logAnalyticsPayGWorkspaceId
    tags: tags
  }
  dependsOn: [
    r_logAnalyticsWorkspace
  ]
}

