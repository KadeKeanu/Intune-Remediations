# Dell SupportAssist Removal

Microsoft Intune Remediation for detecting and removing Dell SupportAssist and related components from managed Windows devices.

## Files

```text
Dell-SupportAssist-Removal/
├── README.md
├── Uninstall-DellSupportAssist_Detection.ps1
└── Uninstall-DellSupportAssist_Remediation.ps1
```

## Purpose

This remediation removes Dell SupportAssist-related software where it is not required, helping standardise managed endpoints and reduce unnecessary software and attack surface.

## Components Detected

- Dell SupportAssist
- Dell SupportAssist for PCs
- Dell SupportAssist Remediation
- SupportAssist Recovery Assistant
- Dell SupportAssist OS Recovery Plugin for Dell Update

## Detection Script

`Uninstall-DellSupportAssist_Detection.ps1`

The script checks both 64-bit and 32-bit Windows uninstall registry locations.

| Exit Code | Result |
|---|---|
| `0` | SupportAssist not detected |
| `1` | SupportAssist detected; remediation required |

An `Exit 1` here triggers Intune Remediation; it does not change the device's Intune Compliance Policy status.

## Remediation Script

`Uninstall-DellSupportAssist_Remediation.ps1`

The remediation attempts silent removal using:

- `QuietUninstallString`, when available.
- MSI product-code uninstall.
- Dell `SupportAssistUninstaller.exe`.

For MSI packages, the script can execute:

```powershell
msiexec.exe /x {PRODUCT-CODE} /qn /norestart
```

## Accepted Exit Codes

| Exit Code | Meaning |
|---|---|
| `0` | Successful |
| `1641` | Successful; restart initiated |
| `3010` | Successful; restart required |

## Verification

After attempting removal, the remediation checks the uninstall registry again. Remaining targeted components cause the remediation to return `Exit 1`; successful removal returns `Exit 0`.

## Recommended Intune Configuration

| Setting | Value |
|---|---|
| Detection script | `Uninstall-DellSupportAssist_Detection.ps1` |
| Remediation script | `Uninstall-DellSupportAssist_Remediation.ps1` |
| Run using logged-on credentials | No |
| Run in 64-bit PowerShell | Yes |
| Execution context | SYSTEM |

## Important

Test against your Dell device models before broad deployment. Dell may change SupportAssist component names, installers, registry entries, and uninstall commands between releases.
