# Intune Remediation - Update All Applications Using WinGet
$LogDirectory = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs"
$LogFile = "$LogDirectory\WinGet-AppUpdate.log"

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

    $Args = @(
        "upgrade","--all","--include-unknown","--silent",
        "--accept-package-agreements","--accept-source-agreements",
        "--disable-interactivity"
    )

    $Output = & $Winget @Args 2>&1
    $ExitCode = $LASTEXITCODE

    $Output | ForEach-Object { Write-Log "UPDATE | $_" }

    if ($ExitCode -eq 0) {
        Write-Output "Remediation successful."
        exit 0
    }

    Write-Output "Remediation failed with WinGet exit code $ExitCode."
    exit 1
}
catch {
    Write-Log "WinGet upgrade failed: $($_.Exception.Message)"
    exit 1
}
