# Intune Remediations

A collection of Microsoft Intune PowerShell detection and remediation scripts for managed Windows devices.

## Repository structure

```text
Intune-Remediations/
├── README.md
├── .gitignore
├── WinGet-Application-Updates/
│   ├── Detection-WinGet-Updates.ps1
│   └── Remediation-WinGet-Update-All.ps1
└── Dell-SupportAssist-Removal/
    ├── Uninstall-DellSupportAssist_Detection.ps1
    └── Uninstall-DellSupportAssist_Remediation.ps1
```

## WinGet Application Updates

The detection script checks for available WinGet application updates. If updates are found, Intune runs the remediation script.

The remediation script runs:

```powershell
winget upgrade --all --include-unknown --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
```

Recommended Intune settings:

| Setting | Value |
|---|---|
| Run using logged-on credentials | No |
| Enforce script signature check | No, unless scripts are signed |
| Run in 64-bit PowerShell | Yes |
| Context | SYSTEM |

Logs:

```text
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGet-Detection.log
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\WinGet-AppUpdate.log
```

## Dell SupportAssist Removal

The detection script checks both 32-bit and 64-bit uninstall registry locations for Dell SupportAssist-related applications.

If SupportAssist is detected, Intune runs the remediation script. The remediation script attempts silent removal using the application's quiet uninstall command, MSI product code, or Dell's SupportAssist uninstaller.

Common successful MSI exit codes `0`, `1641`, and `3010` are accepted.

## Deployment flow

```text
Detection
   ↓
Issue found?
   ├── No  → Exit 0 → No remediation
   └── Yes → Exit 1 → Run remediation
                         ↓
                    Success → Exit 0
                    Failure → Exit 1
```

## Important

Test these scripts with a pilot device group before broad production deployment.

The WinGet script only updates applications that WinGet can identify and for which an update is available from the configured sources.
