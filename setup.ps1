#Requires -Version 7

@(
  'Utils/Utils.psm1',
  'Appinstaller/installer.psm1',
  'Office/installer.psm1',
  'dotfiles/setup.psm1',
  'Terminal/setup.psm1',
  'Windows/tweaks.psm1',
  'wsl/setup.psm1'
) | ForEach-Object {
  Import-Module (Join-Path $PSScriptRoot "modules/$_") -Force
}

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

#------------------------------- Install apps -------------------------------
Write-TitleBox "Installing Apps" -Color Cyan
Install-Choco
Invoke-AppInstallers

#-----------------------------Terminal tweaks--------------------------------
write-TitleBox "Installing Terminal tweaks" -Color Cyan
Set-ProfileForAllHosts
Install-ModulesFromJson
Import-ModulesFromJson
Install-CatppuccinTheme
#-----------------------------Dotfiles---------------------------------------
write-TitleBox "Applying dotfiles" -Color Cyan
Initialize-Dotfiles
#-----------------------------Git Config-------------------------------------
write-TitleBox "Setting up git identity" -Color Cyan
function Set-GitIdentity {

  do {
    $gitName = Read-ColoredInput -Prompt "👤 Enter your Git username: " -Color "Magenta"


    if ([string]::IsNullOrWhiteSpace($gitName)) {
      Write-WarningStyled "Username cannot be empty. Please try again."
    }
  } while ([string]::IsNullOrWhiteSpace($gitName))

  do {
    $gitEmail = Read-ColoredInput -Prompt "📧 Enter your Git email: " -Color "Cyan"
    if (-not (Test-IsValidEmail -Email $gitEmail)) {
      Write-WarningStyled "Invalid email format. Please try again."
    }
  } while (-not (Test-IsValidEmail -Email $gitEmail))

  git config --global user.name "$gitName"
  git config --global user.email "$gitEmail"
  Write-Host ""
  Write-Info "Git username set to: $gitName"
  Write-Info "Git email set to: $gitEmail"
}
Set-GitIdentity

#-----------------------------Windows tweaks--------------------------------
write-TitleBox "Windows tweaks" -Color Cyan
Set-WindowsCustomizations
Remove-Bloatware -AllUsers -Confirm:$false

#-----------------------------Install Office----------------------------------
$installOffice = Read-ColoredInput -Prompt "Do you want to install Office? (y/n): "
if ($installOffice -ieq 'y') {
  Write-TitleBox "Installing Office" -Color Cyan
  if (Install-Office) {
    Write-Info "Activating office..."
    Invoke-RestMethod https://get.activated.win | Invoke-Expression
  }
  else {
    Write-ErrorStyled "Office installation failed."
  }

}
else {
  Write-WarningStyled "Skipping Office installation."
}

#-----------------------------clean temp files----------------------------------
write-TitleBox "Cleaning temp files" -Color Cyan

function Clear-SystemJunk {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param ()

  Write-Info "Cleaning temp files..."

  # Paths to clean
  $tempPaths = @(
    $env:TEMP,
    "$env:WINDIR\Temp"
  )

  foreach ($path in $tempPaths) {
    if (Test-Path $path) {
      try {
        Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Info "Cleared: $path"
      }
      catch {
        Write-WarningStyled "Could not clean ${path}: $_"
      }
    }
    else {
      Write-WarningStyled "Path not found: $path"
    }
  }

  Write-Host "🌐 Flushing DNS..."
  try {
    ipconfig /flushdns | Out-Null
    Write-Info "DNS cache flushed."
  }
  catch {
    Write-ErrorStyled "Failed to flush DNS: $_"
  }

  Write-Info "System cleanup complete."
}

Clear-SystemJunk

#-----------------------------Install WSL-------------------------------------
Write-TitleBox "Installing WSL" -Color Cyan
if (Install-WSL) {
  Install-LinuxDistro -DistroName "archlinux"
  if (Test-WSLDistroExists -DistroName "archlinux") {
    write-info "Setting up Arch Linux..."
    Invoke-ArchSetup


  }
  else {
    Write-ErrorStyled "Arch Linux installation failed."
  }
}
else {
  Write-ErrorStyled "WSL installation failed."
}
#-----------------------------End of script-----------------------------------
