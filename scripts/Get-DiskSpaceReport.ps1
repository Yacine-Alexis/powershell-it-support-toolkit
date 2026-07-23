<#
.SYNOPSIS
Reports local disk capacity and free space levels.

.DESCRIPTION
Queries fixed disks on a local or remote computer and highlights drives that
fall below a defined free space percentage threshold.

.PARAMETER ComputerName
Specifies the computer name to query. Defaults to the local computer.

.PARAMETER ThresholdPercent
Specifies the free space warning threshold percentage.

.EXAMPLE
.\Get-DiskSpaceReport.ps1 -ThresholdPercent 15

.NOTES
Requires: CIM/WMI access to the target system.
Tested on: Windows PowerShell 5.1 on Windows 11.
Risk level: Low. Read-only reporting only.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ComputerName = $env:COMPUTERNAME,

    [Parameter()]
    [Alias('WarningThresholdPercent')]
    [ValidateRange(1, 100)]
    [int]$ThresholdPercent = 15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DiskReportCimInstance {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClassName,

        [Parameter()]
        [string]$Filter
    )

    $cimParameters = @{
        ClassName = $ClassName
    }

    if ($Filter) {
        $cimParameters.Filter = $Filter
    }

    if ($ComputerName -notin @('.', 'localhost', $env:COMPUTERNAME)) {
        $cimParameters.ComputerName = $ComputerName
    }

    Get-CimInstance @cimParameters
}

try {
    Get-DiskReportCimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3" |
        Sort-Object DeviceID |
        Select-Object @(
            @{ Name = 'ComputerName'; Expression = { $ComputerName } },
            @{ Name = 'Drive'; Expression = { $_.DeviceID } },
            @{ Name = 'Label'; Expression = { $_.VolumeName } },
            @{ Name = 'TotalCapacityGB'; Expression = { [math]::Round($_.Size / 1GB, 2) } },
            @{ Name = 'FreeCapacityGB'; Expression = { [math]::Round($_.FreeSpace / 1GB, 2) } },
            @{ Name = 'PercentFree'; Expression = { [math]::Round(($_.FreeSpace / $_.Size) * 100, 2) } },
            @{ Name = 'Status'; Expression = {
                $freePercent = [math]::Round(($_.FreeSpace / $_.Size) * 100, 2)
                if ($freePercent -le $ThresholdPercent) { 'Warning' } else { 'Healthy' }
            } }
        )

    exit 0
}
catch {
    Write-Error "Get-DiskSpaceReport failed: $($_.Exception.Message)"
    exit 1
}
