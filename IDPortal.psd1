#########################################################################
#
# TITLE: IDPortal Cmdlets
# DESCRIPTION: Provides a PowerShell-friendly use of FIMAutomation
# AUTHOR:  Fred Duncan (fr3dd)
# COMPANY: Blue Chip Consulting Group, LLC
# WEBSITE: http://www.bluechip-llc.com
# VERSION: 3.0.2016.1028
#
#Requires -Version 2.0
#Requires -PSSnapin FIMAutomation
#########################################################################

@{

# Script module or binary module file associated with this manifest
ModuleToProcess = 'IDPortal.psm1';

# Version number of this module using the following format - Major.Minor.Build.Revision
# Due to the lack of true source control, the module version uses the following conventions
# Major = Matches the version of PowerShell it is intended for
# Minor = Used to track major code revisions and updates
# Build = The four digit year that it was updated in
# Revision = The month and day it was last updated in the format of MMDD
ModuleVersion = "2.0.2016.1028";

# ID used to uniquely identify this module
# Generate a new GUID with the following commands
#   $guid = [guid]::NewGuid()
#   $newid = $guid.ToString()
GUID = "8556b1b4-11ef-4055-9356-d3084cee1b3a";

# Author of this module
Author = "Fred Duncan";

# Company or vendor of this module
CompanyName = "Blue Chip Consulting Group, LLC";

# Copyright statement for this module
Copyright = "© 2016 Blue Chip Consulting Group. All rights reserved.";

# Description of the functionality provided by this module
Description = "This module contains reusable functions developed and maintained by Blue Chip consultants.";

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = "2.0";

# Name of the Windows PowerShell host required by this module
PowerShellHostName = "";

# Minimum version of the Windows PowerShell host required by this module
PowerShellHostVersion = "2.0";

# Minimum version of the .NET Framework required by this module
DotNetFrameworkVersion = "2.0";

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = "2.0.50727";

# Processor architecture (None, X86, Amd64, IA64) required by this module
ProcessorArchitecture = "None";

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @();

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @();

# Script files (.ps1) that are run in the caller's environment prior to importing this module
ScriptsToProcess = @();

# Type files (.ps1xml) to be loaded when importing this module
TypesToProcess = @();

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = @();

# Modules to import as nested modules of the module specified in ModuleToProcess
NestedModules = @();

# Functions to export from this module
FunctionsToExport = "*";

# Cmdlets to export from this module
CmdletsToExport = "*";

# Variables to export from this module
VariablesToExport = "*";

# Aliases to export from this module
AliasesToExport = "*";

# List of all modules packaged with this module
ModuleList = @();

# List of all files packaged with this module
FileList = @(
	'IDPortal.psd1'
	'IDPortal.psm1'
);

# Private data to pass to the module specified in ModuleToProcess
PrivateData = "";

}