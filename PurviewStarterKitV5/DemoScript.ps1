param (
    [string]$TenantId,
    [string]$CatalogName,
    [string]$CatalogResourceGroup,
    [string]$SubscriptionId,
    [string]$DatafactoryResourceGroup,
    [string]$DatafactoryAccountName,
    [string]$DatafactoryLocation = "East Us",
    [switch]$ConnectToAzure = $false, 
    [switch]$CreateAdfAccountIfNotExists = $false,
    [switch]$UpdateAdfAccountTags = $false,
    [switch]$CreateAzureStorageAccount = $false,
    [string]$AzureStorageAccountName,
    [string]$AzureStorageResourceGroup,
    [string]$AzureStorageLocation= "East Us",
    [switch]$CreateAzureStorageGen2Account = $false,
    [string]$AzureStorageGen2AccountName,
    [string]$AzureStorageGen2ResourceGroup,
    [string]$AzureStorageGen2Location= "East Us",
    [switch]$GenerateDataForAzureStorage = $false,
    [switch]$GenerateDataForAzureStoragetemp = $false,
    [switch]$CopyDataFromAzureStorageToGen2 = $false
)

##############################################################################
##
## Constants
##
##############################################################################

$rootContainer = "starter1"

$rootContainer2 = "starter2"

$dataGenerationPath = ".\dep\dataGenerator\BlobDataCreator.exe"

$storageLinkedServiceDefinition = @"
{
    "name": "<<name>>",
    "properties": {
        "type": "AzureBlobStorage",
        "typeProperties": {
            "connectionString": {
                "value": "<<account_key>>",
                "type": "SecureString"
            }
        }
    }
}
"@

$storageGen2LinkedServiceDefinition = @"
{
    "name": "<<name>>",
    "properties": {
        "type": "AzureBlobFS",
        "typeProperties": {
            "url": "https://<<accountName>>.dfs.core.windows.net",
            "accountKey": {
                "value": "<<account_key>>",
                "type": "SecureString"
            }
        }
    }
}
"@

$azureStorageBlobDataSet = @"
{
    "name": "<<datasetName>>",
    "properties": {
        "linkedServiceName": {
            "referenceName": "<<linkedServiceName>>",
            "type": "LinkedServiceReference"
        },
        "annotations": [],
        "type": "Binary",
        "typeProperties": {
            "location": {
                "type": "AzureBlobStorageLocation",
                "folderPath": "*",
                "container": "<<filesystemname>>"
            }
        }
    },
    "type": "Microsoft.DataFactory/factories/datasets"
}
"@

$azureStorageGen2DataSet = @"
{
    "name": "<<datasetName>>",
    "properties": {
        "linkedServiceName": {
            "referenceName": "<<linkedServiceName>>",
            "type": "LinkedServiceReference"
        },
        "annotations": [],
        "type": "Binary",
        "typeProperties": {
            "location": {
                "type": "AzureBlobFSLocation",
                "fileSystem": "<<filesystemname>>"
            }
        }
    },
    "type": "Microsoft.DataFactory/factories/datasets"
}
"@

$copyPipeline = @"
{
    "name": "demo_<<name>>",
    "properties": {
        "activities": [
            {
                "name": "<<name>>",
                "type": "Copy",
                "policy": {
                    "timeout": "0.01:00:00",
                    "retry": 0,
                    "retryIntervalInSeconds": 30,
                    "secureOutput": false,
                    "secureInput": false
                },
                "userProperties": [],
                "typeProperties": {
                    "source": {
                        "type": "BinarySource",
                        "storeSettings": {
                            "type": "AzureBlobStorageReadSettings",
                            "recursive": true,
                            "wildcardFolderPath": "*"
                        }
                    },
                    "sink": {
                        "type": "BinarySink",
                        "storeSettings": {
                            "type": "AzureBlobFSWriteSettings"
                        }
                    },
                    "enableStaging": false
                },
                "inputs": [
                    {
                        "referenceName": "<<azureStorageLinkedServiceDataSet>>",
                        "type": "DatasetReference"
                    }
                ],
                "outputs": [
                    {
                        "referenceName": "<<azureStorageGen2LinkedServiceDataSet>>",
                        "type": "DatasetReference"
                    }
                ]
            }
        ]
    },
    "type": "Microsoft.DataFactory/factories/pipelines"
}
"@

##############################################################################
##
## Helper functions
##
##############################################################################

#
# Create the resource group if it doesn't exist.
function CreateResourceGroupIfNotExists (
    [string] $resourceGroupName, 
    [string] $resourceLocation) {
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName `
                                         -ErrorAction SilentlyContinue
    if (!$resourceGroup) {
        New-AzResourceGroup -Name $resourceGroupName `
                            -Location $resourceLocation
    }
}

#
# Update the existing Azure Data Factory V2 account with a tag to enable
# lineage information to the specified catalog.
#
function UpdateAzureDataFactoryV2 {
    $catalogEndpoint = "$CatalogName.catalog.purview.azure.com"
    CreateResourceGroupIfNotExists $DatafactoryResourceGroup $DatafactoryLocation
    try {
        $dataFactory = Get-AzDataFactoryV2 -Name $DatafactoryAccountName `
                                           -ResourceGroupName $DatafactoryResourceGroup `
                                           -ErrorAction SilentlyContinue

        if ($dataFactory) {
            Set-AzResource -ResourceId $dataFactory.DataFactoryId -Tag @{catalogUri=$catalogEndpoint} -Force
            Write-Host "Updated Azure Data Factory to emit lineage info to azure data factory $datafactoryAccountName to $catalogEndpoint"
        }
    }
    catch {
        if (!$_.Exception.Message.Contains("not found")) {
            throw "$datafactoryAccountName data factory does not exist"
        }
    }

    if (!$dataFactory) {
        if ($CreateAdfAccountIfNotExists -eq $true) {
        $dataFactory = Set-AzDataFactoryV2 -ResourceGroupName $datafactoryResourceGroup `
                                       -Location $DatafactoryLocation `
                                       -Name $DatafactoryAccountName `
                                       -Tag @{catalogUri=$catalogEndpoint}
        }
    }

    if ($dataFactory) {
        if (!$dataFactory.Identity) {
            Write-Output "Data Factory Identity not found, unable to update the catalog with the ADF managed identity"
        } else {
            Write-Output "Setting the Managed Identity $dataFactory.Identity.PrincipalId on the Catalog: $CatalogName"
            AddDataFactoryManagedIdentityToCatalog -servicePrincipalId $dataFactory.Identity.PrincipalId `
                                                   -catalogName $CatalogName `
                                                   -subscriptionId $SubscriptionId `
                                                   -catalogResourceGroup $CatalogResourceGroup
        }
    } else {
        Write-Error "Unable to find, or create the ADF account"
    }
}

#
# Create a new Azure Storage Account / Gen2 account for the demo.
#
function New-AzureStorageDemoAccount (
    [switch][boolean] $EnableHierarchicalNamespace = $false,
    [string] $AccountName,
    [string] $ResourceGroup,
    [string] $Location) {
    CreateResourceGroupIfNotExists $AzureStorageResourceGroup $AzureStorageLocation
    try {
        $azureStorageAccount = Get-AzStorageAccount -Name $AccountName `
                                                    -ResourceGroupName $ResourceGroup `
                                                    -ErrorAction SilentlyContinue
        if (!$azureStorageAccount) {
            $gen2 = $false
            if ($EnableHierarchicalNamespace -eq $true) {
                $gen2 = $true
            }
            New-AzStorageAccount -Name $AccountName `
                                    -ResourceGroupName $ResourceGroup `
                                    -Location $Location `
                                    -SkuName Standard_LRS `
                                    -Kind StorageV2 `
                                    -EnableHierarchicalNamespace $gen2
        }

        if ($EnableHierarchicalNamespace -eq $true) {
            $accessKey = GetAzureStorageConnectionString -AccountName $AccountName -ResourceGroup $ResourceGroup -OnlyAccessKey
            .\AddContainer.ps1 -StorageAccountName $AccountName -FilesystemName $rootContainer -AccessKey $accessKey
        }
    }
    catch {
        Write-Output $_.Exception.Message
    }
}

#
# Get Storage Account connectionString
#
function GetAzureStorageConnectionString (
    [string] $AccountName,
    [string] $ResourceGroup,
    [switch] $OnlyAccessKey) {
    $azureStorageAccount = Get-AzStorageAccount -Name $AccountName `
                                                    -ResourceGroupName $ResourceGroup `
                                                    -ErrorAction SilentlyContinue
    if (!$azureStorageAccount) {
        throw "Azure Storage account $AccountName not found"
    }
    $accessKeys = Get-AzStorageAccountKey -ResourceGroupName $ResourceGroup `
                                          -Name $AccountName
    $accessKey = ($accessKeys | Where-Object {$_.KeyName -eq "key1"}).Value
    if ($OnlyAccessKey -eq $true) {
        return $accessKey
    }
    return "DefaultEndpointsProtocol=https;AccountName=$AccountName;AccountKey=$accessKey;EndpointSuffix=core.windows.net"
}

#
# Create the linked service
#
function CreateLinkedService (
    [string] $template,
    [string] $name,
    [string] $accountName,
    [string] $accessKey,
    [string] $dataFactoryName,
    [string] $resourceGroup) {
    Remove-Item "$name.json" -ErrorAction SilentlyContinue
    $linkedService = (($template -replace "<<name>>","$name") -replace "<<account_key>>","$accessKey") -replace "<<accountName>>","$accountName"
    $linkedService | Out-File "$name.json"
    Set-AzDataFactoryV2LinkedService -DataFactoryName $dataFactoryName `
                                   -ResourceGroupName $resourceGroup `
                                   -Name $name `
                                   -DefinitionFile "$name.json" `
                                   -Force
    Remove-Item "$name.json" -ErrorAction SilentlyContinue
}

function CreatePipelineAndRunPipeline (
    [string] $pipelineTemplate,
    [string] $name,
    [string] $dataFactoryName,
    [string] $dataFactoryResourceGroup,
    [string] $azureStorageLinkedServiceDatasetName,
    [string] $azureStorageGen2LinkedServiceDatasetName) {
    $fileName = "pipeline-$name.json"
    Remove-Item $fileName -ErrorAction SilentlyContinue
    $template = (($pipelineTemplate -replace "<<name>>",$name) -replace "<<azureStorageLinkedServiceDataSet>>", $azureStorageLinkedServiceDatasetName) -replace "<<azureStorageGen2LinkedServiceDataSet>>", $azureStorageGen2LinkedServiceDatasetName
    $template | Out-File $fileName
    Set-AzDataFactoryV2Pipeline -Name $name `
                                -DefinitionFile $fileName `
                                -ResourceGroupName $dataFactoryResourceGroup `
                                -DataFactoryName $dataFactoryName `
                                -Force
    $runId = Invoke-AzDataFactoryV2Pipeline -ResourceGroupName $dataFactoryResourceGroup `
                                            -DataFactoryName $dataFactoryName `
                                            -PipelineName $name
    Write-Host "Executing Copy pipeline $runId"
    Remove-Item $fileName -ErrorAction SilentlyContinue
}

#
# Create the linked service
#
function CreateDataSet (
    [string] $dataSetName,
    [string] $linkedServiceReference,
    [string] $container,
    [string] $dataFactoryName,
    [string] $resourceGroup,
    [string] $template) {
    Remove-Item "$dataSetName.json" -ErrorAction SilentlyContinue
    $dataSet = (($template -replace "<<datasetName>>","$dataSetName") -replace "<<linkedServiceName>>", "$linkedServiceReference") -replace "<<filesystemname>>","$container"
    $dataSet | Out-File "$dataSetName.json"
    Set-AzDataFactoryV2Dataset -Name $dataSetName `
                               -DefinitionFile "$dataSetName.json" `
                               -Force `
                               -DataFactoryName $dataFactoryName `
                               -ResourceGroupName $resourceGroup
    Remove-Item "$dataSetName.json" -ErrorAction SilentlyContinue
}

function Get-AzCachedAccessToken()
{
    $ErrorActionPreference = 'Stop'
    #$azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    #if(-not $azProfile.Accounts.Count) {
    #    Write-Error "Ensure you have logged in before calling this function."    
    #}
  
    #$currentAzureContext = Get-AzContext
    #$profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    #Write-Debug ("Getting access token for tenant" + $currentAzureContext.Tenant.TenantId)
    #$token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    #$token.AccessToken

    $context = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile.DefaultContext
    [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id.ToString(), $null, [Microsoft.Azure.Commands.Common.Authentication.ShowDialog]::Never, $null, "https://projectbabylon.azure.net").AccessToken
}

function Get-AzBearerToken()
{
    $ErrorActionPreference = 'Stop'
    ('Bearer {0}' -f (Get-AzCachedAccessToken))
}

#
# Add the linked service to
#
function AddDataFactoryManagedIdentityToCatalog (
    [string] $servicePrincipalId,
    [string] $catalogName,
    [string] $subscriptionId,
    [string] $catalogResourceGroup) {
    # Purview Contributor
    $RoleId = "8a3c28859b384fd29d9991af537c1347"
    # Add delay so that service principal is available in the tenant before invoking the function below
    Start-Sleep -Seconds 60
    Write-Output "subscriptionId:$subscriptionId catalogResourceGroup:$catalogResourceGroup catalogName=$catalogName"
    $FullPurviewAccountScope = "/subscriptions/$subscriptionId/resourceGroups/$catalogResourceGroup/providers/Microsoft.Purview/accounts/$catalogName"
    New-AzRoleAssignment -ObjectId $servicePrincipalId -RoleDefinitionId $RoleId -Scope $FullPurviewAccountScope
}

##############################################################################
##
## main()
##
##############################################################################
if(-not (Get-Module Az.Accounts)) {
    Import-Module Az.Accounts
}

if ($ConnectToAzure -eq $true) {
    Connect-AzAccount
}

##
## Select the subscription we'll be operating on.
##
if ($TenantId) {
    Select-AzSubscription -Subscription $SubscriptionId -TenantId $TenantId
} else {
    Write-Output "Unable to select the subscription. Please provide the tenant Id and subscription you're connecting to"
}

##
## Check to see if we are going to update the ADF account
##
if ($UpdateAdfAccountTags -eq $true) {
    if (!$DatafactoryAccountName) {
        throw "Data Factory Account Name needs to be specified"
    }
    if (!$DatafactoryLocation) {
        throw "Data Factory Account Location needs to be specified"
    }
    if (!$DatafactoryResourceGroup) {
        throw "Data Factory Account Resource Group needs to be specified"
    }
    UpdateAzureDataFactoryV2
}

##
## Check to see if we are going to create a demo azure storage account
##
if ($CreateAzureStorageAccount -eq $true) {
    if (!$AzureStorageAccountName) {
        throw "Azure Storage Name needs to be specified"
    }
    if (!$AzureStorageLocation) {
        throw "Azure Storage Location needs to be specified"
    }
    if (!$AzureStorageResourceGroup) {
        throw "Azure Storage Resource Group needs to be specified"
    }
    New-AzureStorageDemoAccount -AccountName $AzureStorageAccountName `
                                -ResourceGroup $AzureStorageResourceGroup `
                                -Location $AzureStorageLocation
}

##
## Check to see if we are going to create a demo ADLS Gen2 account
##
if ($CreateAzureStorageGen2Account -eq $true) {
    if (!$AzureStorageGen2AccountName) {
        throw "Azure Storage Gen2 Name needs to be specified"
    }
    if (!$AzureStorageGen2Location) {
        throw "Azure Storage Gen2 Location needs to be specified"
    }
    if (!$AzureStorageGen2ResourceGroup) {
        throw "Azure Storage Gen2 Resource Group needs to be specified"
    }
    New-AzureStorageDemoAccount -AccountName $AzureStorageGen2AccountName `
                                -ResourceGroup $AzureStorageGen2ResourceGroup `
                                -Location $AzureStorageGen2Location `
                                -EnableHierarchicalNamespace
}

##
## Upload data to the Azure Data Account
##
if ($GenerateDataForAzureStorage -eq $true) {
    if (!$AzureStorageAccountName) {
        throw "Azure Storage Name needs to be specified"
    }
    if (!$AzureStorageResourceGroup) {
        throw "Azure Storage Resource Group needs to be specified"
    }
    $connectionString = GetAzureStorageConnectionString -AccountName $AzureStorageAccountName `
                                                        -ResourceGroup $AzureStorageResourceGroup
    Start-Process -FilePath $dataGenerationPath `
                  -ArgumentList "-nf 100 -n $rootContainer -s AzureStorage -c $connectionString" `
                  -WorkingDirectory ".\dep\dataGenerator\" `
				  -Wait

}

if ($CopyDataFromAzureStorageToGen2 -eq $true) {
    if (!$AzureStorageAccountName) {
        throw "Azure Storage Name needs to be specified"
    }
    if (!$AzureStorageResourceGroup) {
        throw "Azure Storage Resource Group needs to be specified"
    }
    if (!$AzureStorageGen2AccountName) {
        throw "Azure Storage Gen2 Name needs to be specified"
    }
    if (!$AzureStorageGen2ResourceGroup) {
        throw "Azure Storage Gen2 Resource Group needs to be specified"
    }
    if (!$DatafactoryAccountName) {
        throw "Data Factory Account Name must be defined"
    }
    $azureStorageConnectionString = GetAzureStorageConnectionString -AccountName $AzureStorageAccountName `
                                                                    -ResourceGroup $AzureStorageResourceGroup
    $azureStorageGen2ConnectionString = GetAzureStorageConnectionString -AccountName $AzureStorageGen2AccountName `
                                                                        -ResourceGroup $AzureStorageGen2ResourceGroup `
                                                                        -OnlyAccessKey
    # Create the linked Services
    # TODO: remove hard-coded linkedService and dataset names
    CreateLinkedService -template $storageLinkedServiceDefinition `
                        -name azureStorageLinkedService `
                        -accessKey $azureStorageConnectionString `
                        -dataFactoryName $DatafactoryAccountName `
                        -resourceGroup $DatafactoryResourceGroup `
                        -accountName $AzureStorageAccountName
    CreateDataSet -dataSetName azureStorageLinkedServiceDataSet `
                  -linkedServiceReference azureStorageLinkedService `
                  -container $rootContainer `
                  -dataFactoryName $DatafactoryAccountName `
                  -resourceGroup $DatafactoryResourceGroup `
                  -template $azureStorageBlobDataSet
    
    # Create the datasets we'll copy from to
    CreateLinkedService -template $storageGen2LinkedServiceDefinition `
                        -name azureStorageGen2LinkedService `
                        -accessKey $azureStorageGen2ConnectionString `
                        -dataFactoryName $DatafactoryAccountName `
                        -resourceGroup $DatafactoryResourceGroup `
                        -accountName $AzureStorageGen2AccountName
    CreateDataSet -dataSetName azureStorageGen2LinkedServiceDataSet `
                  -linkedServiceReference azureStorageGen2LinkedService `
                  -container $rootContainer `
                  -dataFactoryName $DatafactoryAccountName `
                  -resourceGroup $DatafactoryResourceGroup `
                  -template $azureStorageGen2DataSet

    # Create the Azure Data Factory Pipeline
    CreatePipelineAndRunPipeline -pipelineTemplate $copyPipeline `
                   -dataFactoryName $DatafactoryAccountName `
                   -dataFactoryResourceGroup $DatafactoryResourceGroup `
                   -azureStorageLinkedServiceDatasetName azureStorageLinkedServiceDataSet `
                   -azureStorageGen2LinkedServiceDatasetName azureStorageGen2LinkedServiceDataSet `
                   -name 'TestCopyPipeline'
}
##
## Upload temp data to the Azure Data Account which is not subject to copy activity
##
if ($GenerateDataForAzureStoragetemp -eq $true) {
    if (!$AzureStorageAccountName) {
        throw "Azure Storage Name needs to be specified"
    }
    if (!$AzureStorageResourceGroup) {
        throw "Azure Storage Resource Group needs to be specified"
    }
    $connectionString = GetAzureStorageConnectionString -AccountName $AzureStorageAccountName `
                                                        -ResourceGroup $AzureStorageResourceGroup
    Start-Process -FilePath $dataGenerationPath `
                  -ArgumentList "-nf 50 -n $rootContainer2 -s AzureStorage -c $connectionString -e" `
                  -WorkingDirectory ".\dep\dataGenerator\" `
				  -Wait

}