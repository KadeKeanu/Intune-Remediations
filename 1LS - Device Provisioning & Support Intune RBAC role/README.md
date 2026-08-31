# 1LS - Device Provisioning & Support

Creates a custom **Microsoft Intune RBAC role** for first-line Windows device provisioning and support.

## Files

- `New-1LS-DeviceProvisioningSupportRole.ps1`
- `README.md`

## Purpose

The role is intended to replace unnecessarily broad **Intune Administrator** access for 1LS staff who primarily need to provision and support Windows devices.

Microsoft recommends using the least-privileged Intune role that can perform the required administrative task.

## Intended Permissions

The script requests and validates permissions for:

### Enrollment Programs / Windows Autopilot

- Read device
- Read profile
- Assign profile
- Sync device

### Managed Device Support

- Read managed devices
- Set primary user
- Sync devices
- Restart devices
- Collect diagnostics
- Autopilot Reset

### Read-Only Troubleshooting

- Read device configurations
- View device configuration reports
- Read device compliance policies
- View compliance reports
- Read organization information

## Deliberately Excluded

The role is designed **not** to provide broad administrative control. It does not intentionally grant:

- Intune Administrator
- Intune RBAC role administration
- Create/update/delete configuration profiles
- Create/update/delete compliance policies
- Security baseline management
- Application management
- Enrollment token management
- Tenant-wide policy administration
- Wipe or Retire by default

Add higher-impact remote actions only after confirming a business requirement.

## Why the Script Validates Permissions

Intune custom roles contain internal `allowedResourceActions` strings.

Rather than hard-coding undocumented or stale action names, the script reads the role definitions exposed by the tenant and attempts to uniquely map each requested friendly permission to the current action name.

If any requested permission cannot be uniquely resolved, the script **stops without creating the role**. This is intentional.

## Requirements

- PowerShell 5.1+ or PowerShell 7+
- Microsoft Intune subscription
- `Microsoft.Graph.Authentication`
- Microsoft Graph delegated permission:
  - `DeviceManagementRBAC.ReadWrite.All`
- Sufficient Intune RBAC authority
- Recommended administrative role: **Intune Role Administrator**

## Test First

Run:

```powershell
.\New-1LS-DeviceProvisioningSupportRole.ps1 -WhatIf
```

The script will connect to Microsoft Graph, discover the current Intune RBAC actions, validate the requested permissions, and show the intended operation without creating the role.

## Create the Role

```powershell
.\New-1LS-DeviceProvisioningSupportRole.ps1
```

Sign in using an appropriately privileged administrative account when prompted.

## Assign the Role

The script creates the **role definition only**.

Intune RBAC roles are assigned to groups rather than directly to individual users.

After creation:

1. Open the Microsoft Intune admin center.
2. Go to **Tenant administration > Roles > All roles**.
3. Open **1LS - Device Provisioning & Support**.
4. Select **Assignments > Assign**.
5. Add the Entra security group containing the authorized 1LS administrators.
6. Configure the appropriate **Scope Groups**.
7. Configure **Scope Tags** if your organization uses them.
8. Review and create the assignment.

## Scope Recommendation

Do not automatically use **All users** and **All devices**.

Scope the role to the devices and users that 1LS genuinely needs to support. Intune permissions from multiple role assignments are cumulative, so also review any other RBAC roles held by the same administrators.

## Autopilot User Assignment

Assigning or unassigning a user from a Windows Autopilot device is an Intune service configuration operation.

If your 1LS workflow specifically requires Autopilot **Assign user / Unassign user**, validate this operation with a pilot account after the custom role is created. Microsoft Graph exposes the Autopilot user-assignment operation under `DeviceManagementServiceConfig.ReadWrite.All` for Graph API access; Intune console RBAC and Graph API OAuth permissions are separate authorization layers.

Do not grant broad Graph API permissions to 1LS users merely to compensate for an incorrectly scoped Intune RBAC role.

## Pilot

Recommended rollout:

1. Create the custom role.
2. Create/use a small 1LS pilot security group.
3. Assign the custom role to the pilot group.
4. Restrict Scope Groups appropriately.
5. Test:
   - View Windows devices
   - View Autopilot devices
   - Sync Autopilot device
   - Assign an approved Autopilot profile
   - View compliance/configuration state
   - Set primary user
   - Sync managed device
   - Restart device
   - Collect diagnostics
   - Autopilot Reset
   - Autopilot user assignment/unassignment if required
6. Confirm prohibited policy-management actions are unavailable.
7. Only then remove broader Intune Administrator access.

## Security

Always use `-WhatIf` first.

Custom RBAC roles should be reviewed periodically as 1LS responsibilities and Microsoft Intune permissions change.

Never store tenant IDs, credentials, access tokens, secrets, or real user email addresses in the repository.
