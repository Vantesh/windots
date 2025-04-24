
@('Utils/Utils.psm1', 'Appinstaller/installer.psm1') | ForEach-Object { Import-Module (Join-Path $PSScriptRoot "modules/$_") -Force }

if (-not (Test-IsAdmin)) {
  Write-ErrorStyled "This script requires administrative privileges. Please run as administrator."
  return
}
if (-not (Test-IsOnline)) {
  Write-WarningStyled "NO INTERNET CONNECTION AVAILABLE!"
  for ($countdown = 3; $countdown -ge 0; $countdown--) {
    Write-ColorText "`r{DarkGray}Automatically exit this script in {Red}$countdown second(s){DarkGray}..." -NoNewLine
    Start-Sleep -Seconds 1
  }
  exit

}

if (-not(Get-Command choco -ErrorAction SilentlyContinue)) {
  Install-Choco
}
Write-TitleBox "Installing Apps" -Color Cyan
Invoke-AppInstallers
