<#
.SYNOPSIS
    Assigns least-privilege Microsoft Entra support roles to a user.

.DESCRIPTION
    GitHub-ready PowerShell script that assigns one or more built-in Microsoft Entra roles
    to a user by UPN.

    Default roles:
      - Helpdesk Administrator
      - Teams Communications Support Engineer

    The script:
      - Installs Microsoft.Graph.Authentication if required
      - Connects to Microsoft Graph using delegated permissions
      - Resolves the user by UPN
      - Resolves each role by display name
      - Checks whether the assignment already exists
      - Creates only missing assignments
      - Supports -WhatIf

    NOTE:
      This script assigns Microsoft Entra directory roles.
      It does NOT create or assign a custom Microsoft Intune RBAC role.

.REQUIREMENTS
    - PowerShell 5.1+ or PowerShell 7+
    - Microsoft.Graph.Authentication module
    - The signed-in administrator must have sufficient privilege to assign directory roles.
      Microsoft documents Privileged Role Administrator as the least-privileged built-in role
      for creating directory role assignments.
    - Delegated Microsoft Graph permission:
      RoleManagement.ReadWrite.Directory

.PARAMETER UserPrincipalName
    UPN of the user who will receive the role assignment.

.PARAMETER RoleNames
    One or more Microsoft Entra built-in role display names.

.EXAMPLE
    .\Assign-1LS-SupportRoles.ps1 -UserPrincipalName "alex.wilber@example.com"

.EXAMPLE
    .\Assign-1LS-SupportRoles.ps1 `
        -UserPrincipalName "alex.wilber@example.com" `
        -RoleNames "Teams Communications Support Engineer"

.EXAMPLE
    .\Assign-1LS-SupportRoles.ps1 `
        -UserPrincipalName "alex.wilber@example.com" `
        -WhatIf

.NOTES
    Author: IT Operations
    Version: 1.0.0
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string[]]$RoleNames = @(
        'Helpdesk Administrator',
        'Teams Communications Support Engineer'
    )
)

$ErrorActionPreference = 'Stop'

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK]   $Message" -ForegroundColor Green
}

function Write-WarningMessage {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Ensure-GraphAuthenticationModule {
    if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
        Write-Info "Microsoft.Graph.Authentication is not installed."
        Write-Info "Installing Microsoft.Graph.Authentication for the current user..."

        Install-Module Microsoft.Graph.Authentication `
            -Scope CurrentUser `
            -Repository PSGallery `
            -Force `
            -AllowClobber
    }

    Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
}

function Escape-ODataString {
    param([Parameter(Mandatory)][string]$Value)
    return $Value.Replace("'", "''")
}

try {
    Ensure-GraphAuthenticationModule

    Write-Info "Connecting to Microsoft Graph..."
    Connect-MgGraph `
        -Scopes 'RoleManagement.ReadWrite.Directory' `
        -NoWelcome

    $context = Get-MgContext
    if (-not $context) {
        throw "Microsoft Graph connection could not be established."
    }

    Write-Success "Connected to Microsoft Graph as $($context.Account)."

    $escapedUpn = Escape-ODataString -Value $UserPrincipalName
    $userUri = "https://graph.microsoft.com/v1.0/users?`$filter=userPrincipalName eq '$escapedUpn'&`$select=id,displayName,userPrincipalName"

    Write-Info "Resolving user: $UserPrincipalName"
    $userResponse = Invoke-MgGraphRequest -Method GET -Uri $userUri
    $users = @($userResponse.value)

    if ($users.Count -eq 0) {
        throw "User '$UserPrincipalName' was not found."
    }

    if ($users.Count -gt 1) {
        throw "More than one user was returned for '$UserPrincipalName'. Aborting."
    }

    $user = $users[0]
    Write-Success "Found user: $($user.displayName) <$($user.userPrincipalName)>"

    foreach ($roleName in $RoleNames) {
        Write-Host ""
        Write-Info "Processing role: $roleName"

        $escapedRoleName = Escape-ODataString -Value $roleName
        $roleUri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions?`$filter=displayName eq '$escapedRoleName'&`$select=id,displayName,isBuiltIn,isEnabled"

        $roleResponse = Invoke-MgGraphRequest -Method GET -Uri $roleUri
        $roles = @($roleResponse.value)

        if ($roles.Count -eq 0) {
            Write-WarningMessage "Role '$roleName' was not found. Skipping."
            continue
        }

        if ($roles.Count -gt 1) {
            Write-WarningMessage "Multiple role definitions matched '$roleName'. Skipping for safety."
            continue
        }

        $role = $roles[0]

        if ($role.isEnabled -eq $false) {
            Write-WarningMessage "Role '$roleName' is disabled. Skipping."
            continue
        }

        $assignmentUri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$($user.id)' and roleDefinitionId eq '$($role.id)' and directoryScopeId eq '/'&`$select=id,principalId,roleDefinitionId,directoryScopeId"

        $assignmentResponse = Invoke-MgGraphRequest -Method GET -Uri $assignmentUri
        $existingAssignments = @($assignmentResponse.value)

        if ($existingAssignments.Count -gt 0) {
            Write-Success "'$roleName' is already assigned to $UserPrincipalName."
            continue
        }

        if ($PSCmdlet.ShouldProcess(
            $UserPrincipalName,
            "Assign Microsoft Entra role '$roleName' at tenant scope"
        )) {
            $body = @{
                '@odata.type'    = '#microsoft.graph.unifiedRoleAssignment'
                roleDefinitionId = $role.id
                principalId      = $user.id
                directoryScopeId = '/'
            } | ConvertTo-Json

            Invoke-MgGraphRequest `
                -Method POST `
                -Uri 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments' `
                -Body $body `
                -ContentType 'application/json' | Out-Null

            Write-Success "Assigned '$roleName' to $UserPrincipalName."
        }
    }

    Write-Host ""
    Write-Success "Role assignment processing completed."
}
catch {
    Write-Error "Failed: $($_.Exception.Message)"
    exit 1
}
finally {
    if (Get-MgContext) {
        Disconnect-MgGraph | Out-Null
    }
}
