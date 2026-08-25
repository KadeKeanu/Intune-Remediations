# Intune Remediation - Dell SupportAssist Removal
$ErrorActionPreference = "Stop"

$TargetApplications = @(
    "Dell SupportAssist",
    "Dell SupportAssist for PCs",
    "Dell SupportAssist Remediation",
    "SupportAssist Recovery Assistant",
    "Dell SupportAssist OS Recovery Plugin for Dell Update"
)

$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

function Write-Log {
    param([string]$Message)
    Write-Output "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $Message"
}

try {
    $DetectedApps = foreach ($RegistryPath in $RegistryPaths) {
        Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue |
        Where-Object {
            if ([string]::IsNullOrWhiteSpace($_.DisplayName)) { return $false }
            foreach ($Target in $TargetApplications) {
                if ($_.DisplayName -like "*$Target*") { return $true }
            }
            return $false
        } |
        Select-Object DisplayName, DisplayVersion, UninstallString, QuietUninstallString, PSChildName
    }

    $DetectedApps = $DetectedApps | Sort-Object DisplayName, PSChildName -Unique

    if (-not $DetectedApps) {
        Write-Output "Nothing to remove."
        exit 0
    }

    $FailedApps = @()

    foreach ($App in $DetectedApps) {
        try {
            $ExitCode = $null

            if ($App.QuietUninstallString) {
                $CommandLine = $App.QuietUninstallString
                if ($CommandLine -match '^\s*"([^"]+)"\s*(.*)$') {
                    $Executable = $Matches[1]
                    $Arguments = $Matches[2]
                } else {
                    $Parts = $CommandLine -split '\s+', 2
                    $Executable = $Parts[0]
                    $Arguments = if ($Parts.Count -gt 1) { $Parts[1] } else { "" }
                }

                $Process = Start-Process -FilePath $Executable -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
                $ExitCode = $Process.ExitCode
            }
            elseif ($App.UninstallString -match '(?i)msiexec') {
                $Guid = $null
                if ($App.UninstallString -match '\{[A-Fa-f0-9\-]+\}') {
                    $Guid = $Matches[0]
                } elseif ($App.PSChildName -match '^\{[A-Fa-f0-9\-]+\}$') {
                    $Guid = $App.PSChildName
                }

                if (-not $Guid) { throw "Unable to determine MSI product GUID." }

                $Process = Start-Process -FilePath "msiexec.exe" `
                    -ArgumentList "/x $Guid /qn /norestart" `
                    -Wait -PassThru -WindowStyle Hidden
                $ExitCode = $Process.ExitCode
            }
            elseif ($App.UninstallString -match '(?i)SupportAssistUninstaller\.exe') {
                $UninstallString = $App.UninstallString.Trim()
                if ($UninstallString -match '^\s*"([^"]+)"') {
                    $Executable = $Matches[1]
                } else {
                    $Executable = ($UninstallString -split '\s+')[0]
                }

                if (-not (Test-Path $Executable)) {
                    throw "SupportAssist uninstaller not found: $Executable"
                }

                $Process = Start-Process -FilePath $Executable `
                    -ArgumentList "/arp /S" `
                    -Wait -PassThru -WindowStyle Hidden
                $ExitCode = $Process.ExitCode
            }
            else {
                throw "Unsupported uninstall method: $($App.UninstallString)"
            }

            if ($ExitCode -notin @(0,1641,3010)) {
                throw "Uninstaller returned exit code $ExitCode."
            }

            Write-Log "$($App.DisplayName) removal completed successfully."
        }
        catch {
            Write-Log "ERROR removing $($App.DisplayName): $($_.Exception.Message)"
            $FailedApps += $App.DisplayName
        }
    }

    Start-Sleep -Seconds 3

    $RemainingApps = foreach ($RegistryPath in $RegistryPaths) {
        Get-ItemProperty -Path $RegistryPath -ErrorAction SilentlyContinue |
        Where-Object {
            if ([string]::IsNullOrWhiteSpace($_.DisplayName)) { return $false }
            foreach ($Target in $TargetApplications) {
                if ($_.DisplayName -like "*$Target*") { return $true }
            }
            return $false
        }
    }

    if ($FailedApps.Count -gt 0 -or $RemainingApps) {
        Write-Output "Remediation failed."
        exit 1
    }

    Write-Output "All detected Dell SupportAssist components were successfully removed."
    exit 0
}
catch {
    Write-Output "Fatal remediation error: $($_.Exception.Message)"
    exit 1
}
