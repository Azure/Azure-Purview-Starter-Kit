param (
    [string]$CatalogName,
    [string]$TenantId,
    [string]$SubscriptionId,
    [string]$ResourceGroup,
    [string]$CatalogResourceGroup,
    [string]$StorageBlobName = $ResourceGroup + "adcblob",
    [string]$AdlsGen2Name = $ResourceGroup + "adcadls",
    [string]$DataFactoryName = $ResourceGroup + "adcfactory",
    [switch]$ConnectToAzure = $false
)

if ($ConnectToAzure -eq $true) {
    .\demoscript.ps1 .\demoscript.ps1 -ConnectToAzure `
                -SubscriptionId $SubscriptionId `
                -TenantId $TenantId
}
else {
    .\demoscript.ps1 -CreateAdfAccountIfNotExists `
                 -UpdateAdfAccountTags `
                 -DatafactoryAccountName $DataFactoryName `
                 -DatafactoryResourceGroup $ResourceGroup `
                 -CatalogName $CatalogName `
                 -GenerateDataForAzureStorage `
                 -GenerateDataForAzureStoragetemp `
                 -AzureStorageAccountName $StorageBlobName `
                 -CreateAzureStorageAccount `
                 -CreateAzureStorageGen2Account `
                 -AzureStorageGen2AccountName $AdlsGen2Name `
                 -CopyDataFromAzureStorageToGen2 `
                 -TenantId $TenantId `
                 -SubscriptionId $SubscriptionId `
                 -AzureStorageResourceGroup $ResourceGroup `
                 -AzureStorageGen2ResourceGroup $ResourceGroup `
                 -CatalogResourceGroup $CatalogResourceGroup
}