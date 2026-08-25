# Intune Remediations

A growing collection of PowerShell scripts designed for Microsoft Intune Remediations and Windows endpoint management.

This repository contains detection and remediation scripts for automating common IT administration, application management, security, and endpoint maintenance tasks.

## Repository Structure

```text
Intune-Remediations/
├── README.md
├── WinGet-Application-Updates/
│   ├── README.md
│   ├── Detection-WinGet-Updates.ps1
│   └── Remediation-WinGet-Update-All.ps1
└── Dell-SupportAssist-Removal/
    ├── README.md
    ├── Uninstall-DellSupportAssist_Detection.ps1
    └── Uninstall-DellSupportAssist_Remediation.ps1
```

## Available Remediations

### WinGet Application Updates
Detects applications with available WinGet updates and attempts to update all supported applications silently.

### Dell SupportAssist Removal
Detects and removes Dell SupportAssist and related components from managed Windows devices.

## How Intune Remediations Work

- Detection `Exit 0` = No remediation required.
- Detection `Exit 1` = Remediation required.
- Remediation `Exit 0` = Remediation successful.
- Remediation `Exit 1` = Remediation failed.

## Recommended Intune Settings

| Setting | Recommended Value |
|---|---|
| Run using logged-on credentials | No |
| Run as | SYSTEM |
| Run in 64-bit PowerShell | Yes |
| Enforce script signature check | No, unless scripts are signed |

## Deployment Recommendations

1. Review the PowerShell scripts.
2. Test on a small pilot group.
3. Review detection and remediation results.
4. Confirm device and application behaviour.
5. Expand deployment gradually.

## Logging

Where applicable, scripts write logs to:

```text
C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\
```

## Disclaimer

Review and test all scripts before production deployment. Application installers, registry locations, vendor software, WinGet packages, and Windows behaviour can change over time.
