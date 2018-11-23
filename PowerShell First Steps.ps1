#Alte AzureRM Module entfernen
Get-Module -ListAvailable -Name "AzureRM*"
Get-Module -ListAvailable -Name "AzureRM*" | Uninstall-Module -Force

#Installiert die Azure PowerShell – Cross-platform “Az” module.
Install-Module -Name Az

#Welche Versions-Stand habe ich?
$installed = get-module -ListAvailable -Name "Az*" |  Group-Object -Property Name | % {$_.Group | Sort-Object Version -Descending | select-object -first 1}

#find latest version online
$available = Find-Module -Name Az*

"Installed`t Availabe `t Module Name"
"--------------------------------------"
#complete comparison
foreach ($item in $installed)
{
   "{1}`t {2} `t {0}" -f $item.name,$item.Version,$(switch (($available | where Name -eq $item.Name).Version -eq $item.Version)
{
    $true {" = latest"}
    $false {" < " +($available | where Name -eq $item.Name).Version}
})
} 

#Welche Befehle habe ich denn jetzt?
Get-Command -Module Az.*

#An Azure anmelden:
Login-AzAccount 

#Eine VM erstellen:
New-AzVM

