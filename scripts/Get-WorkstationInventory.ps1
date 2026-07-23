<#
.SYNOPSIS
Collects workstation inventory details for support documentation.

.DESCRIPTION
Queries a local or remote Windows workstation for operating system, hardware,
disk, network, and user session information. The script can also export a
summary of the collected data to JSON or CSV for ticket attachments.

.PARAMETER ComputerName
Specifies the computer name to inventory. Defaults to the local computer.

.PARAMETER ExportFormat
Specifies whether to export the collected inventory to JSON or CSV.

.PARAMETER OutputPath
Specifies the path for the exported file. If omitted, a default file name is used.

.EXAMPLE
.\Get-WorkstationInventory.ps1 -ComputerName WS-042 -ExportFormat Json -OutputPath .\ws-042.json

.NOTES
Requires: CIM/WMI access to the target system.
Tested on: Windows PowerShell 5.1 on Windows 11.
Risk level: Low. Read-only unless export is requested.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ComputerName = $env:COMPUTERNAME,

    [Parameter()]
    [ValidateSet('None', 'Json', 'Csv')]
    [string]$ExportFormat = 'None',

    [Parameter()]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-InventoryCimInstance {
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
    $computerSystem = Get-InventoryCimInstance -ClassName Win32_ComputerSystem
    $operatingSystem = Get-InventoryCimInstance -ClassName Win32_OperatingSystem
    $bios = Get-InventoryCimInstance -ClassName Win32_BIOS
    $processor = Get-InventoryCimInstance -ClassName Win32_Processor | Select-Object -First 1
    $logicalDisks = Get-InventoryCimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3" |
        Sort-Object DeviceID |
        Select-Object DeviceID, VolumeName,
            @{ Name = 'TotalCapacityGB'; Expression = { [math]::Round($_.Size / 1GB, 2) } },
            @{ Name = 'FreeCapacityGB'; Expression = { [math]::Round($_.FreeSpace / 1GB, 2) } },
            @{ Name = 'PercentFree'; Expression = { [math]::Round(($_.FreeSpace / $_.Size) * 100, 2) } }
    $networkAdapters = Get-InventoryCimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True" |
        Select-Object Description, MACAddress, IPAddress, DefaultIPGateway, DNSServerSearchOrder

    $inventory = [PSCustomObject]@{
        ComputerName    = $computerSystem.Name
        WindowsVersion  = $operatingSystem.Caption
        OSVersion       = $operatingSystem.Version
        Manufacturer    = $computerSystem.Manufacturer
        Model           = $computerSystem.Model
        BIOSVersion     = $bios.SMBIOSBIOSVersion
        CPU             = $processor.Name
        TotalRAMGB      = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
        DiskSpace       = $logicalDisks
        IPConfiguration = $networkAdapters
        LoggedInUser    = $computerSystem.UserName
        LastBootTime    = $operatingSystem.LastBootUpTime
    }

    if ($ExportFormat -ne 'None') {
        if (-not $OutputPath) {
            $extension = $ExportFormat.ToLowerInvariant()
            $OutputPath = ".\\$ComputerName-workstation-inventory.$extension"
        }

        if ($PSCmdlet.ShouldProcess($OutputPath, "Export workstation inventory as $ExportFormat")) {
            switch ($ExportFormat) {
                'Json' {
                    $inventory | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding UTF8
                }
                'Csv' {
                    [PSCustomObject]@{
                        ComputerName   = $inventory.ComputerName
                        WindowsVersion = $inventory.WindowsVersion
                        OSVersion      = $inventory.OSVersion
                        Manufacturer   = $inventory.Manufacturer
                        Model          = $inventory.Model
                        BIOSVersion    = $inventory.BIOSVersion
                        CPU            = $inventory.CPU
                        TotalRAMGB     = $inventory.TotalRAMGB
                        DiskSummary    = ($inventory.DiskSpace | ForEach-Object {
                            "{0} {1}GB free of {2}GB" -f $_.DeviceID, $_.FreeCapacityGB, $_.TotalCapacityGB
                        }) -join '; '
                        IPAddresses     = ($inventory.IPConfiguration | ForEach-Object { $_.IPAddress }) -join '; '
                        LoggedInUser    = $inventory.LoggedInUser
                        LastBootTime    = $inventory.LastBootTime
                    } | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
                }
            }
        }
    }

    $inventory
    exit 0
}
catch {
    Write-Error "Get-WorkstationInventory failed: $($_.Exception.Message)"
    exit 1
}
