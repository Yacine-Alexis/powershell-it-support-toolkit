<#
.SYNOPSIS
Performs a basic network connectivity triage sequence.

.DESCRIPTION
Tests the local TCP/IP stack, default gateway, external IP reachability,
DNS resolution, reachability to a target host, and an optional TCP port.
The script reports clear pass or fail messages without modifying configuration.

.PARAMETER Target
Specifies the hostname or IP address to test.

.PARAMETER Port
Specifies an optional TCP port to test against the target.

.PARAMETER PingCount
Specifies how many ICMP echo requests to send for ping-based checks.

.EXAMPLE
.\Test-NetworkConnectivity.ps1 -Target github.com -Port 443

.NOTES
Requires: Network access and Test-NetConnection.
Tested on: Windows PowerShell 5.1 on Windows 11.
Risk level: Low. Read-only diagnostic checks only.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Target,

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$Port,

    [Parameter()]
    [ValidateRange(1, 10)]
    [int]$PingCount = 2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-NetworkResult {
    param(
        [string]$Step,
        [bool]$Passed,
        [string]$Details,
        [string]$LikelyIssue = ''
    )

    [PSCustomObject]@{
        Step        = $Step
        Passed      = $Passed
        Details     = $Details
        LikelyIssue = $LikelyIssue
    }
}

try {
    $results = New-Object System.Collections.Generic.List[object]
    $defaultGateway = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter "IPEnabled = True" |
        Where-Object { $_.DefaultIPGateway } |
        Select-Object -First 1 -ExpandProperty DefaultIPGateway |
        Select-Object -First 1

    $localStackPassed = Test-Connection -ComputerName '127.0.0.1' -Count 1 -Quiet -ErrorAction SilentlyContinue
    $results.Add((New-NetworkResult -Step 'Local TCP/IP stack' -Passed $localStackPassed -Details 'Loopback ping to 127.0.0.1' -LikelyIssue 'TCP/IP stack issue on the local workstation'))

    if ($defaultGateway) {
        $gatewayPassed = Test-Connection -ComputerName $defaultGateway -Count $PingCount -Quiet -ErrorAction SilentlyContinue
        $results.Add((New-NetworkResult -Step 'Default gateway reachable' -Passed $gatewayPassed -Details "Gateway: $defaultGateway" -LikelyIssue 'Local network path or gateway availability issue'))
    }
    else {
        $results.Add((New-NetworkResult -Step 'Default gateway reachable' -Passed $false -Details 'No default gateway detected' -LikelyIssue 'DHCP or static gateway configuration issue'))
    }

    $externalPassed = Test-Connection -ComputerName '8.8.8.8' -Count $PingCount -Quiet -ErrorAction SilentlyContinue
    $results.Add((New-NetworkResult -Step 'External IP reachable' -Passed $externalPassed -Details 'ICMP test to 8.8.8.8' -LikelyIssue 'Internet connectivity or upstream firewall issue'))

    $targetIsIp = $Target -match '^(?:\d{1,3}\.){3}\d{1,3}$'
    if ($targetIsIp) {
        $results.Add((New-NetworkResult -Step 'DNS resolution' -Passed $true -Details 'Target is already an IP address' -LikelyIssue ''))
    }
    else {
        try {
            $dnsRecord = Resolve-DnsName -Name $Target -ErrorAction Stop | Select-Object -First 1
            $results.Add((New-NetworkResult -Step 'DNS resolution' -Passed $true -Details "Resolved to $($dnsRecord.IPAddress)" -LikelyIssue ''))
        }
        catch {
            $results.Add((New-NetworkResult -Step 'DNS resolution' -Passed $false -Details "Unable to resolve $Target" -LikelyIssue 'Configured DNS server or DNS client cache issue'))
        }
    }

    $targetReachable = Test-Connection -ComputerName $Target -Count $PingCount -Quiet -ErrorAction SilentlyContinue
    $results.Add((New-NetworkResult -Step 'Target reachable' -Passed $targetReachable -Details "ICMP test to $Target" -LikelyIssue 'Remote host unavailable, filtered, or offline'))

    if ($PSBoundParameters.ContainsKey('Port')) {
        $portTest = Test-NetConnection -ComputerName $Target -Port $Port -WarningAction SilentlyContinue
        $results.Add((New-NetworkResult -Step "TCP port $Port reachable" -Passed ([bool]$portTest.TcpTestSucceeded) -Details "Remote address: $($portTest.RemoteAddress)" -LikelyIssue 'Application listener, local firewall, or remote firewall issue'))
    }

    foreach ($result in $results) {
        if ($result.Passed) {
            Write-Output "[PASS] $($result.Step)"
        }
        else {
            Write-Output "[FAIL] $($result.Step)"
            Write-Output "Likely issue: $($result.LikelyIssue)"
        }
    }

    if ($results.Passed -contains $false) {
        exit 1
    }

    exit 0
}
catch {
    Write-Error "Test-NetworkConnectivity failed: $($_.Exception.Message)"
    exit 2
}
