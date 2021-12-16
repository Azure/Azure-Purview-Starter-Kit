param (
    [Parameter(Mandatory=$true)]
    [string]$CatalogName,
    [Parameter(Mandatory=$true)]
    [string]$Location,
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroup,
    [Parameter(Mandatory=$true)]
    [string]$CatalogResourceGroup,
    [string]$StorageBlobName = "pvdemo$( -join ((0x61..0x7A) | Get-Random -Count 5  | % {[char]$_}) )adcblob",
    [string]$AdlsGen2Name    = "pvdemo$( -join ((0x61..0x7A) | Get-Random -Count 5  | % {[char]$_}) )adcadls",
    [string]$DataFactoryName = "pvdemo$( -join ((0x61..0x7A) | Get-Random -Count 5  | % {[char]$_}) )adcfactory",
    [switch]$ConnectToAzure = $false
)

    Connect-AzAccount   -SubscriptionId $SubscriptionId    -TenantId $TenantId
    Set-AzContext       -SubscriptionId $SubscriptionId    -TenantId $TenantId
    
    Write-Host "Creating Azure Resource Group for Purview Account.... [ " $CatalogResourceGroup " ] "
    New-AzResourceGroup `
        -Name $CatalogResourceGroup `
        -Location $Location
        
    $PurviewTemplate = Get-Content -Path .\purview_template.json
    $PurviewTemplate -replace 'PURVIEW_ACCOUNT_NAME_CHANGE_BEFORE_RUNNING', $CatalogName | Set-Content -Path .\purview_template_modified.json
    $PurviewTemplate = Get-Content -Path .\purview_template_modified.json
    $PurviewTemplate -replace 'LOCATION_CHANGE_BEFORE_RUNNING', $Location | Set-Content -Path .\purview_template_modified.json

    Write-Host "Creating Purview Account.... [ " $CatalogName " ] "
    New-AzResourceGroupDeployment `
		-ResourceGroupName $CatalogResourceGroup `
		-TemplateFile .\purview_template_modified.json

    .\demoscript.ps1 -CreateAdfAccountIfNotExists `
		-UpdateAdfAccountTags `
		-DatafactoryAccountName $DataFactoryName `
		-DatafactoryResourceGroup $ResourceGroup `
    -DatafactoryLocation $Location `
		-CatalogName $CatalogName `
		-AzureStorageAccountName $StorageBlobName `
		-CreateAzureStorageAccount `
		-CreateAzureStorageGen2Account `
		-AzureStorageGen2AccountName $AdlsGen2Name `
    -AzureStorageLocation $Location `
		-CopyDataFromAzureStorageToGen2 `
		-TenantId $TenantId `
		-SubscriptionId $SubscriptionId `
		-AzureStorageResourceGroup $ResourceGroup `
		-AzureStorageGen2ResourceGroup $ResourceGroup `
    -AzureStorageGen2Location $Location `
		-CatalogResourceGroup $CatalogResourceGroup 
  #  -GenerateDataForAzureStorage $false
  #  -GenerateDataForAzureStoragetemp $false
