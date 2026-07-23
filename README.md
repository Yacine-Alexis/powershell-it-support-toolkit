# powershell-it-support-toolkit

Beginner-friendly PowerShell scripts for Windows diagnostics, network troubleshooting, system inventory, and Active Directory administration.

## Starter Contents

- `scripts/Get-WorkstationInventory.ps1` collects workstation inventory details and can export them to JSON or CSV.
- `scripts/Test-NetworkConnectivity.ps1` runs a step-by-step connectivity triage against a hostname or IP.
- `scripts/Get-DiskSpaceReport.ps1` reports free space for local fixed disks and flags low free space.
- `scripts/Export-ADUserInventory.ps1` exports Active Directory user details from a lab environment to CSV.
- `examples/` contains sample output for inventory and network checks.
- `documentation/` contains script standards and testing notes.
- `tests/` is reserved for Pester coverage as the toolkit grows.

## Quick Start

Run scripts from PowerShell in the repository root:

```powershell
.\scripts\Get-WorkstationInventory.ps1
.\scripts\Get-WorkstationInventory.ps1 -ExportFormat Json -OutputPath .\inventory.json
.\scripts\Test-NetworkConnectivity.ps1 -Target github.com -Port 443
.\scripts\Get-DiskSpaceReport.ps1 -ThresholdPercent 20
```

To export Active Directory users:

```powershell
.\scripts\Export-ADUserInventory.ps1 -Path .\ad-users.csv -EnabledOnly
```

## Notes

- `Export-ADUserInventory.ps1` requires the `ActiveDirectory` module.
- Remote CIM queries may require appropriate firewall rules and permissions.
- `Test-NetworkConnectivity.ps1` is diagnostic only and does not modify network settings.
- This repository is licensed under the MIT License.
