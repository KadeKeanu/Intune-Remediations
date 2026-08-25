# Intune Remediation - WinGet Detection
$LogDirectory = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = "$LogDirectory\WinGet-Detection.log"

if (-not (Test-Path $LogDirectory)) {
    New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
}

function Write-Log {
    param([string]$Message)
    $Entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | $Message"
    Write-Output $Entry
    Add-Content -Path $LogFile -Value $Entry
}

$Winget = $null
$WingetCommand = Get-Command winget.exe -ErrorAction SilentlyContinue
if ($WingetCommand) { $Winget = $WingetCommand.Source }

if (-not $Winget) {
    $WingetPackage = Get-ChildItem "C:\Program Files\WindowsApps" -Directory `
        -Filter "Microsoft.DesktopAppInstaller_*__8wekyb3d8bbwe" `
        -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1

    if ($WingetPackage) {
        $PossibleWinget = Join-Path $WingetPackage.FullName "winget.exe"
        if (Test-Path $PossibleWinget) { $Winget = $PossibleWinget }
    }
}

if (-not $Winget) {
    Write-Log "WinGet could not be located."
    exit 1
}

try {
    & $Winget source update --accept-source-agreements --disable-interactivity 2>&1 |
        ForEach-Object { Write-Log "SOURCE | $_" }

    $UpgradeOutput = & $Winget upgrade --include-unknown --accept-source-agreements --disable-interactivity 2>&1
    $ExitCode = $LASTEXITCODE
    $OutputText = $UpgradeOutput | Out-String

    $UpgradeOutput | ForEach-Object { Write-Log "CHECK | $_" }

    if ($ExitCode -ne 0) { exit 1 }

    if ($OutputText -match "No applicable upgrade found" -or
        $OutputText -match "No installed package found matching input criteria") {
        Write-Output "No WinGet application updates available."
        exit 0
    }

    Write-Output "WinGet application updates are available."
    exit 1
}
catch {
    Write-Log "Detection failed: $($_.Exception.Message)"
    exit 1
}
