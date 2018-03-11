#
# Module manifest for module 'DbSmo'
#
# Generated by: Cody Konior
#
# Generated on: 10/01/2016
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'DbSmo.psm1'

# Version number of this module.
ModuleVersion = '1.4.0.8'

# ID used to uniquely identify this module
GUID = '6feec22b-a827-4846-8bcd-c5a15c255ed3'

# Author of this module
Author = 'Cody Konior'

# Company or vendor of this module
CompanyName = 'Cody Konior'

# Copyright statement for this module
Copyright = '(c) 2016 Cody Konior. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Retrieve all SMO/WMI properties for a server and store in auto-created temporal tables'

# Minimum version of the Windows PowerShell engine required by this module
# PowerShellVersion = ''

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of the .NET Framework required by this module
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @(
    "Jojoba", 
    "Performance",
    "SqlServer"
    )

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module
FunctionsToExport = @(
    "Add-DbSmo",
	"Add-DbWmi",
    "ConvertFrom-DbSmo",
    "Add-DbDeleteTemporalProcedure"
)

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all modules packaged with this module.
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

