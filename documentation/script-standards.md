# Script Standards

Use these conventions for every script in this repository.

## Standard Header

Each script should begin with this comment-based help structure:

```powershell
<#
.SYNOPSIS
Brief description.

.DESCRIPTION
What the script checks or changes.

.PARAMETER
Description of accepted parameters.

.EXAMPLE
Example command.

.NOTES
Requires:
Tested on:
Risk level:
#>
```

## Coding Standards

- Use descriptive variable names.
- Validate input with attributes such as `ValidateNotNullOrEmpty`, `ValidateSet`, or `ValidateRange`.
- Use `try/catch` around operations that can fail and write actionable error messages.
- Avoid destructive defaults. Read-only behavior should be the default unless the script exists specifically to make changes.
- Support `-WhatIf` for scripts that make changes or write exports.
- Never hard-code credentials, tokens, or secrets.
- Return meaningful exit codes for success, handled failures, and unexpected failures when the script is intended to run unattended.
- Log errors clearly with `Write-Error`, and use `Write-Verbose` for diagnostic detail.
- Add comments for reasoning, assumptions, or non-obvious tradeoffs rather than obvious syntax.

## Output Standards

- Return structured objects whenever practical.
- Keep console-only status messages short and consistent.
- Avoid `Format-Table` and `Format-List` inside reusable scripts.
- Document export formats and sample output in the repository when useful for support teams.

## Safety Standards

- Fail fast when a required module, permission, or environment dependency is missing.
- Keep lab-only or high-impact scripts clearly labeled in the help header.
- Exclude password data and other unnecessary sensitive information from reports.
