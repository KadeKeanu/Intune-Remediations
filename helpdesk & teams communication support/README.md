# 1LS Microsoft Entra Support Role Assignment

PowerShell script for assigning least-privilege Microsoft Entra support roles to 1LS/helpdesk users.

## Script

`Assign-1LS-SupportRoles-GitHub.ps1`

## Default Roles

The script assigns the following built-in Microsoft Entra roles by default:

- **Helpdesk Administrator**
- **Teams Communications Support Engineer**

The script does **not** assign the full Intune Administrator or Teams Administrator roles.

> **Important:** This script manages Microsoft Entra directory role assignments. It does not create or assign a custom Microsoft Intune RBAC role.

## What the Script Does

The script:

- Connects securely to Microsoft Graph.
- Looks up the target user using their User Principal Name (UPN).
- Resolves the requested Microsoft Entra roles by display name.
- Checks whether each role is already assigned.
- Assigns only roles that are missing.
- Supports PowerShell `-WhatIf` for testing before making changes.
- Disconnects from Microsoft Graph when processing is complete.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Internet access to Microsoft Graph
- `Microsoft.Graph.Authentication` PowerShell module
- An administrator account permitted to assign Microsoft Entra directory roles
- Microsoft Graph delegated permission:
  - `RoleManagement.ReadWrite.Directory`

If the Microsoft Graph Authentication module is not installed, the script attempts to install it for the current user.

## Usage

### Test First

Always test the assignment before making changes:

```powershell
.\Assign-1LS-SupportRoles-GitHub.ps1 `
    -UserPrincipalName "alex.wilber@example.com" `
    -WhatIf
```

### Assign the Default 1LS Roles

```powershell
.\Assign-1LS-SupportRoles-GitHub.ps1 `
    -UserPrincipalName "alex.wilber@example.com"
```

The user will receive:

- Helpdesk Administrator
- Teams Communications Support Engineer

### Assign Only Helpdesk Administrator

```powershell
.\Assign-1LS-SupportRoles-GitHub.ps1 `
    -UserPrincipalName "alex.wilber@example.com" `
    -RoleNames "Helpdesk Administrator"
```

### Assign Only Teams Communications Support Engineer

```powershell
.\Assign-1LS-SupportRoles-GitHub.ps1 `
    -UserPrincipalName "alex.wilber@example.com" `
    -RoleNames "Teams Communications Support Engineer"
```

### Specify Multiple Roles

```powershell
.\Assign-1LS-SupportRoles-GitHub.ps1 `
    -UserPrincipalName "jamie.taylor@example.com" `
    -RoleNames @(
        "Helpdesk Administrator",
        "Teams Communications Support Engineer"
    )
```

## Why These Roles?

The purpose of this approach is to reduce the need to provide 1LS/helpdesk personnel with broad administrative roles.

### Helpdesk Administrator

Intended for common identity-related helpdesk activities such as user support and limited authentication/password administration.

### Teams Communications Support Engineer

Intended for advanced troubleshooting of Microsoft Teams calls and meetings, including access to call analytics and communication troubleshooting information.

Because this role can expose detailed call information, access should only be granted to support personnel who require it.

## Intune Access

Windows Autopilot and Intune device-management permissions should be handled separately using **Intune RBAC**.

For example, an organization could create a custom role such as:

`1LS - Device Provisioning & Support`

That role can be restricted to the specific Intune permissions required for:

- Viewing managed devices
- Windows Autopilot operations
- Assigning/unassigning Autopilot users
- Setting the primary user
- Device sync
- Device restart
- Collecting diagnostics
- Autopilot Reset, where required
- Viewing compliance and configuration status

This provides a clearer separation between **device support** and **tenant-wide Intune administration**.

## Security Recommendations

Before deploying the script:

1. Use `-WhatIf` to validate the intended assignment.
2. Confirm that the target UPN is correct.
3. Review whether the user genuinely requires both roles.
4. Avoid granting broader administrator roles when these roles satisfy the support requirement.
5. Regularly review role assignments and remove access that is no longer required.
6. Consider Microsoft Entra Privileged Identity Management (PIM) for eligible/time-limited privileged access where available.

## Example Repository Structure

```text
Microsoft-365/
└── Entra-ID/
    └── RBAC/
        ├── Assign-1LS-SupportRoles-GitHub.ps1
        └── README.md
```

## Disclaimer

Test this script in a controlled environment before production deployment.

Role assignments are privileged security changes. The administrator running the script remains responsible for confirming that the requested access is appropriate for the target user and organization.
