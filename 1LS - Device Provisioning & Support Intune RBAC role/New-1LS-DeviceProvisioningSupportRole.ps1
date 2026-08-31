<#
.SYNOPSIS
    Creates the Microsoft Intune custom RBAC role:
    "1LS - Device Provisioning & Support"

.DESCRIPTION
    Creates a least-privilege Intune custom role intended for first-line
    Windows device provisioning and support.

    IMPORTANT:
    Intune RBAC permission action names can evolve. This script first reads
    the tenant's Intune role definitions and maps the requested permissions
    from Microsoft's exposed action names. It refuses to create the role if
    a requested action cannot be resolved, rather than silently granting a
    different permission.

    The script creates the ROLE DEFINITION only. Assign the role separately
    to an Entra security group and appropriate Scope Groups/Scope Tags.

.REQUIREMENTS
    - PowerShell 5.1+ or PowerShell 7+
    - Microsoft.Graph.Authentication
    - Active Microsoft Intune tenant/license
    - Microsoft Graph delegated permission:
        DeviceManagementRBAC.ReadWrite.All
    - Administrator with sufficient Intune RBAC authority
    - Recommended: Intune Role Administrator

.EXAMPLE
    .\New-1LS-DeviceProvisioningSupportRole.ps1 -WhatIf

.EXAMPLE
    .\New-1LS-DeviceProvisioningSupportRole.ps1

.NOTES
    GitHub-safe: contains no tenant-specific usernames, email addresses,
    tenant IDs, group IDs, or secrets.
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$RoleName = '1LS - Device Provisioning & Support',

    [string]$Description = 'Least-privilege Intune RBAC role for 1LS Windows Autopilot provisioning, user/device support, diagnostics, and approved remote device actions.'
)

$ErrorActionPreference = 'Stop'

# Requested permissions are expressed as friendly labels.
# The script resolves their current action names from Intune before creation.
$RequestedPermissions = @(
    # Windows Autopilot / Enrollment Programs
    @{ Category = 'Enrollment programs'; Action = 'Read device' },
    @{ Category = 'Enrollment programs'; Action = 'Read profile' },
    @{ Category = 'Enrollment programs'; Action = 'Assign profile' },
    @{ Category = 'Enrollment programs'; Action = 'Sync device' },

    # Read-only configuration/compliance visibility
    @{ Category = 'Device configurations'; Action = 'Read' },
    @{ Category = 'Device configurations'; Action = 'View Reports' },
    @{ Category = 'Device compliance policies'; Action = 'Read' },
    @{ Category = 'Device compliance policies'; Action = 'View Reports' },
    @{ Category = 'Organization'; Action = 'Read' },

    # Managed-device support
    @{ Category = 'Managed devices'; Action = 'Read' },
    @{ Category = 'Managed devices'; Action = 'Set primary user' },
    @{ Category = 'Managed devices'; Action = 'Sync devices' },
    @{ Category = 'Managed devices'; Action = 'Restart Now' },
    @{ Category = 'Managed devices'; Action = 'Collect diagnostics' },
    @{ Category = 'Managed devices'; Action = 'Autopilot Reset' }
)

function Ensure-GraphModule {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        Write-Host '[INFO] Installing Microsoft.Graph.Authentication...' -ForegroundColor Cyan
        Install-Module Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force -AllowClobber
    }
    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
}

function Get-IntuneRoleDefinitions {
    $uri = 'https://graph.microsoft.com/v1.0/deviceManagement/roleDefinitions'
    $all = @()

    do {
        $response = Invoke-MgGraphRequest -Method GET -Uri $uri
        if ($response.value) { $all += @($response.value) }
        $uri = $response.'@odata.nextLink'
    } while ($uri)

    return $all
}

function Get-AvailableResourceActions {
    param([array]$RoleDefinitions)

    $actions = New-Object System.Collections.Generic.HashSet[string]

    foreach ($role in $RoleDefinitions) {
        foreach ($permission in @($role.rolePermissions)) {
            foreach ($resourceAction in @($permission.resourceActions)) {
                foreach ($action in @($resourceAction.allowedResourceActions)) {
                    if ($action) { [void]$actions.Add([string]$action) }
                }
            }
        }
    }

    return @($actions)
}

function Resolve-FriendlyPermission {
    param(
        [string]$Category,
        [string]$Action,
        [string[]]$AvailableActions
    )

    # Normalize words and look for an action containing both the category
    # concept and action concept. We intentionally require one unique match.
    $categoryWords = ($Category -replace '[^A-Za-z0-9 ]',' ' -split '\s+' |
        Where-Object { $_.Length -gt 2 })
    $actionWords = ($Action -replace '[^A-Za-z0-9 ]',' ' -split '\s+' |
        Where-Object { $_.Length -gt 1 })

    $matches = foreach ($candidate in $AvailableActions) {
        $flat = ($candidate -replace '[^A-Za-z0-9]','').ToLowerInvariant()

        $categoryScore = 0
        foreach ($word in $categoryWords) {
            if ($flat.Contains($word.ToLowerInvariant())) { $categoryScore++ }
        }

        $actionScore = 0
        foreach ($word in $actionWords) {
            if ($flat.Contains($word.ToLowerInvariant())) { $actionScore++ }
        }

        if ($categoryScore -ge 1 -and $actionScore -eq $actionWords.Count) {
            [PSCustomObject]@{
                Name  = $candidate
                Score = ($categoryScore * 10) + $actionScore
            }
        }
    }

    $best = @($matches | Sort-Object Score -Descending)
    if (-not $best) { return $null }

    $topScore = $best[0].Score
    $top = @($best | Where-Object Score -eq $topScore)

    if ($top.Count -ne 1) { return $null }
    return $top[0].Name
}

try {
    Ensure-GraphModule

    Write-Host '[INFO] Connecting to Microsoft Graph...' -ForegroundColor Cyan
    Connect-MgGraph -Scopes 'DeviceManagementRBAC.ReadWrite.All' -NoWelcome

    Write-Host '[INFO] Reading Intune RBAC role definitions...' -ForegroundColor Cyan
    $definitions = @(Get-IntuneRoleDefinitions)
    if ($definitions.Count -eq 0) {
        throw 'No Intune role definitions were returned.'
    }

    $existing = @($definitions | Where-Object { $_.displayName -eq $RoleName })
    if ($existing.Count -gt 0) {
        throw "A role named '$RoleName' already exists. No changes were made."
    }

    $availableActions = @(Get-AvailableResourceActions -RoleDefinitions $definitions)
    if ($availableActions.Count -eq 0) {
        throw 'Could not discover Intune RBAC resource actions from this tenant.'
    }

    $resolved = @()
    $unresolved = @()

    foreach ($permission in $RequestedPermissions) {
        $actionName = Resolve-FriendlyPermission `
            -Category $permission.Category `
            -Action $permission.Action `
            -AvailableActions $availableActions

        if ($actionName) {
            $resolved += $actionName
            Write-Host "[OK] $($permission.Category) -> $($permission.Action)" -ForegroundColor Green
            Write-Host "     $actionName"
        }
        else {
            $unresolved += "$($permission.Category) -> $($permission.Action)"
            Write-Warning "Could not uniquely resolve: $($permission.Category) -> $($permission.Action)"
        }
    }

    if ($unresolved.Count -gt 0) {
        Write-Host ''
        Write-Host '[STOP] The role was NOT created.' -ForegroundColor Red
        Write-Host 'The following permissions require manual verification in this tenant:'
        $unresolved | ForEach-Object { Write-Host "  - $_" }
        throw 'Permission validation failed. Review the current Intune permission names before creating the role.'
    }

    $resolved = @($resolved | Sort-Object -Unique)

    $body = @{
        '@odata.type' = '#microsoft.graph.deviceAndAppManagementRoleDefinition'
        displayName   = $RoleName
        description   = $Description
        isBuiltIn     = $false
        rolePermissions = @(
            @{
                '@odata.type' = '#microsoft.graph.rolePermission'
                resourceActions = @(
                    @{
                        '@odata.type' = '#microsoft.graph.resourceAction'
                        allowedResourceActions    = $resolved
                        notAllowedResourceActions = @()
                    }
                )
            }
        )
    } | ConvertTo-Json -Depth 10

    Write-Host ''
    Write-Host "[INFO] Validated $($resolved.Count) Intune RBAC actions." -ForegroundColor Cyan

    if ($PSCmdlet.ShouldProcess($RoleName, 'Create Intune custom RBAC role')) {
        $created = Invoke-MgGraphRequest `
            -Method POST `
            -Uri 'https://graph.microsoft.com/v1.0/deviceManagement/roleDefinitions' `
            -Body $body `
            -ContentType 'application/json'

        Write-Host ''
        Write-Host "[SUCCESS] Created Intune custom role: $($created.displayName)" -ForegroundColor Green
        Write-Host "Role ID: $($created.id)"
        Write-Host ''
        Write-Host 'NEXT STEP:'
        Write-Host 'Intune admin center -> Tenant administration -> Roles -> All roles'
        Write-Host "Open '$RoleName' -> Assignments -> Assign"
        Write-Host 'Assign it to an Entra SECURITY GROUP, then configure Scope Groups and Scope Tags.'
    }
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    if (Get-MgContext) {
        Disconnect-MgGraph | Out-Null
    }
}
