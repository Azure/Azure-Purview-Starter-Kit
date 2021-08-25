# Project : Azure Purview Starter Kit Using PowerShell Commands & Purview API

Hi Purview folks 

Good day ! Today I'm going to talk about getting started and being up and running with a fresh new (clean install) Azure Purview deployment in a matter of minutes.

Here's an updated post giving you detailed steps on how to get started with Azure Purview and be up and running getting to the stage of running your first scan successfully on various types of Azure data sources. HTML View of this article [Original Link](https://techcommunity.microsoft.com/t5/azure-purview/getting-started-with-azure-purview-using-purview-starter-kit/m-p/2671432) 

**Materials/Artefacts**

1) [Purview Starter Kit V5](https://github.com/Azure/Azure-Purview-Starter-Kit/blob/main/PurviewStarterKitV5.zip) (part of this Git Repo)

2) [Watch Video](https://youtu.be/8BG4_i1kbzE) Full video demonstrating entire set of steps, starting from executing the Purview starter kit; setting correct parameters, logging in to the Azure portal, creating a new sample Azure Data Lake Storage Gen2, an Azure Blob Storage account and one Azure Data Factory to copy sample data between the Blob and ADLSGen2 storage accounts and show sample lineage information.


**Steps To Execute**

1) Extract the attached (PurviewStarterKitV5 to a folder of your choice,

2) Then open PowerShell as administrator by right clicking in the same folder, and navigate to the folder where PurviewStarterKitV5 was extracted.

3) Change the parameters (CatalogName , TenantID, SubscriptionId , ResourceGroup , CatalogResourceGroup , Location) below as per your choice. 

Note : Before you run the PowerShell scripts to bootstrap the catalog, get the values of the following arguments to use in the scripts:

*TenantID:* In the Azure portal, select Azure Active Directory. In the Manage section of the left navigation pane, select Properties. Then select the copy icon for Tenant ID to save the value to your clipboard. Paste the value in a text editor for later use.

*SubscriptionID:* In the Azure portal, search for and select the name of the Azure Purview instance that you created as a prerequisite. Select the Overview section and save the GUID for the Subscription ID.

*CatalogName:* The name of the Azure Purview account. Note that CatalogName is the name of your purview account as well as the Purview MSI that gets created automatically. You will need this name to add "reader" role permission on your Purview MSI in order to successfully set up and scan your data sources.
CatalogResourceGroupName: The name of the resource group in which you created your Azure Purview account.

*Location:* The region where your Purview account and resource groups will be created. Be sure to modify the region in purview_template.json file as well. Regions supported by Purview are : 
eastus2euap,eastus,westeurope,southeastasia,canadacentral,southcentralus,brazilsouth,centralindia,uksouth,australiaeast,northeurope,westcentralus,westus2,eastus2

For example: Following is a valid command to execute the attached script. Be sure to use only [ a-z OR A-Z OR 0-9 ] characters while supplying the ResourceGroup and CatalogName parameters. 

 
```powershell
 .\RunStarterKitFullAuto.ps1 `
-CatalogName ARIBANPURVIEW20210999 `
-TenantId 72f976887688bf-86f1-41af-91ab-2d78798c9d011db47 `
-SubscriptionId 8c2c7768768b23-848d-40fe-b817-69786780d79ad9dfd `
-ResourceGroup ariban20210999 `
-CatalogResourceGroup managed-rg-aribanpurview20210999 `
-Location "East US"
```

Watch the video below for a full walkthrough ! Let me know your experience or any questions in the comments below.

https://youtu.be/8BG4_i1kbzE

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft 
trademarks or logos is subject to and must follow 
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.
