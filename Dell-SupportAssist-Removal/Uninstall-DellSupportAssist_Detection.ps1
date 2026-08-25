# Intune Remediation - Dell SupportAssist Detection
$ErrorActionPreference = "Stop"

$TargetApplications = @(
    "Dell SupportAssist",
    "Dell SupportAssist for PCs",
    "Dell SupportAssist OS Recovery Plugin for Dell Update",
    "Dell SupportAssist Remediation",
    "SupportAssist Recovery Assistant"
)

$RegistryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

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
        Select-Object DisplayName, DisplayVersion, Publisher, UninstallString, QuietUninstallString, PSChildName
    }

    $DetectedApps = $DetectedApps | Sort-Object DisplayName, DisplayVersion -Unique

    if ($DetectedApps) {
        Write-Output "Dell SupportAssist components detected. Remediation required."
        $DetectedApps | ForEach-Object {
            Write-Output "Application: $($_.DisplayName) | Version: $($_.DisplayVersion)"
        }
        exit 1
    }

    Write-Output "Dell SupportAssist is not installed. No remediation required."
    exit 0
}
catch {
    Write-Output "Dell SupportAssist detection failed: $($_.Exception.Message)"
    exit 1
}
