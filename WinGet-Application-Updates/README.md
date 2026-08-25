# WinGet Application Updates

Microsoft Intune Remediation for automatically detecting and updating applications managed through Windows Package Manager (WinGet).

## Files

```text
WinGet-Application-Updates/
├── README.md
├── Detection-WinGet-Updates.ps1
└── Remediation-WinGet-Update-All.ps1
```

## Purpose

This remediation helps keep supported Windows applications updated automatically, reducing outdated software, vulnerabilities, and manual application maintenance.

## Detection Script

`Detection-WinGet-Updates.ps1`

The script locates WinGet, refreshes package sources, and checks for available application upgrades.

| Exit Code | Result |
|---|---|
| `0` | No application updates detected |
| `1` | Updates detected or remediation required |

## Remediation Script

`Remediation-WinGet-Update-All.ps1`

The remediation runs:

```powershell
winget upgrade --all --include-unknown --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
```

| Parameter | Purpose |
|---|---|
| `--all` | Upgrade all applicable packages |
| `--include-unknown` | Include packages with unknown installed versions |
| `--silent` | Request silent installation |
| `--accept-package-agreements` | Accept package agreements |
| `--accept-source-agreements` | Accept source agreements |
| `--disable-interactivity` | Prevent user prompts |

## Logging

```text
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGet-Detection.log
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGet-AppUpdate.log
```

## Recommended Intune Configuration

| Setting | Value |
|---|---|
| Detection script | `Detection-WinGet-Updates.ps1` |
| Remediation script | `Remediation-WinGet-Update-All.ps1` |
| Run using logged-on credentials | No |
| Run in 64-bit PowerShell | Yes |
| Execution context | SYSTEM |

## Important

WinGet cannot update every application installed on Windows. Applications must be recognised by WinGet and have an applicable update available through a configured source.

Test against a pilot device group before broad deployment.
