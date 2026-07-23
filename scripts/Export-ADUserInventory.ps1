<#
.SYNOPSIS
Exports an Active Directory user inventory from a lab environment.

.DESCRIPTION
Collects a user inventory from Active Directory and exports usernames,
display names, enabled state, OU, department, group membership, and last
logon information to CSV. The script does not retrieve password data.

.PARAMETER Path
Specifies the CSV file path for the exported inventory.

.PARAMETER SearchBase
Specifies an optional distinguished name to limit the search scope.

.PARAMETER EnabledOnly
Exports only enabled user accounts.

.EXAMPLE
.\Export-ADUserInventory.ps1 -SearchBase "OU=Lab Users,DC=contoso,DC=com" -EnabledOnly

.NOTES
Requires: ActiveDirectory module and an AD lab environment.
Tested on: Windows PowerShell 5.1 with RSAT Active Directory tools.
Risk level: Low. Reads directory data and writes a CSV export.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Path = '.\ad-user-inventory.csv',

    [Parameter()]
    [string]$SearchBase,

    [Parameter()]
    [switch]$EnabledOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

try {
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        throw 'The ActiveDirectory module is required to run this script.'
    }

    Import-Module ActiveDirectory

    $getAdUserParameters = @{
        Filter     = '*'
        Properties = @('DisplayName', 'Department', 'Enabled', 'DistinguishedName', 'LastLogonDate', 'MemberOf')
    }

    if ($SearchBase) {
        $getAdUserParameters.SearchBase = $SearchBase
    }

    $users = Get-ADUser @getAdUserParameters

    if ($EnabledOnly) {
        $users = $users | Where-Object { $_.Enabled }
    }

    $inventory = $users |
        Sort-Object SamAccountName |
        Select-Object @(
            @{ Name = 'Username'; Expression = { $_.SamAccountName } },
            @{ Name = 'DisplayName'; Expression = { $_.DisplayName } },
            @{ Name = 'Enabled'; Expression = { $_.Enabled } },
            @{ Name = 'OU'; Expression = {
                ($_.DistinguishedName -split ',', 2)[1]
            } },
            @{ Name = 'Department'; Expression = { $_.Department } },
            @{ Name = 'GroupMembership'; Expression = {
                if ($_.MemberOf) {
                    ($_.MemberOf | ForEach-Object { ($_ -split ',')[0] -replace '^CN=' }) -join '; '
                }
                else {
                    ''
                }
            } },
            @{ Name = 'LastLogonDate'; Expression = { $_.LastLogonDate } },
            @{ Name = 'LastLogonNote'; Expression = { 'LastLogonDate can be stale or incomplete across domain controllers.' } }
        )

    if ($PSCmdlet.ShouldProcess($Path, 'Export Active Directory user inventory to CSV')) {
        $inventory | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }

    $inventory
    exit 0
}
catch {
    Write-Error "Export-ADUserInventory failed: $($_.Exception.Message)"
    exit 1
}
