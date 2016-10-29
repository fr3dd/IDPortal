Microsoft Forefront Identity Manager and Microsoft Identity Manager Portal environments.
## Features
* Provides a more PowerShell-friendly way to leverage the Microsoft FIMAutomation snap-in
* Provides a way to execute XPath queries and see the results in a PowerShell collection
* Provides the ability to make single or multiple object updates

## Supported Environments
* Microsoft Forefront Identity Manager (FIM) Portal
* Microsoft Identity Manager (MIM) Portal

## Installation

### Source Code
1. Download the source code from GitHub repo
2. Create the following directory ( C:\Users\<profile>\Documents\WindowsPowerShell\Modules\IDPortal )
3. Copy the IDPortal.psm1 file into the new directory
4. Copy the IDPortal.psd1 file into the new directory
5. Check to make sure that the execution policy on the machine is `RemoteSigned` or `Unrestricted`
6. Check the two files to make sure that they are not blocked from the properties (this can happen depending on how you get the files to the new folder)

### Supported PowerShell Versions
* Windows Management Framework 2
* Windows Management Framework 3
* Windows Management Framework 4
* Windows Management Framework 5

### Requirements
* Microsoft _FIMAutomation_ snap-in (installed by default on a FIM/MIM portal server)

## Get Started
Once you have followed the installation steps, you will need to load the module. While this module may be used in scripts, it is mainly intended for Adhoc processes and reporting. You can start using the module by importing it:

`Import-Module IDPortal`

You will be presented with a welcome screen that has some default variable information and values. The following 'built-in' variables are used to control what system you are connecting to and where the schema data is located. Here are the three special variables:

### $IDPortalCredential
This variable is used if you need to supply a credential instead of using the currently logged on user. By default, this value is `$null`

### $IDPortalDataDirectory
This variable is used to store schema files for objects that you plan to use. The schema files are generated automatically the first time that you query an object that does not have a corresponding schema file. The purpose of this file is to provide the underlying cmdlets information about what portal attributes are available and specific data type information. All update operations will inspect the schema file to see if the target attribute exists and the type is correct before sending the request to the service through the Import-FIMCconfig cmdlet.

### $IDPortalServiceUri
This variable is used to target the cmdlets to the appropriate FIM/MIM portal environment. Since this module is typically run from the portal server directly, this value should not have to change.

## Get Help
All cmdlets contain simple help so that you can explore the capabilities right inside the shell.
