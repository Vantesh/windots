function Install-WSL {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param ()

  $wslInstalled = Get-Command wsl.exe -ErrorAction SilentlyContinue

  if (-not $wslInstalled) {
    Write-Info "WSL is not installed. Installing WSL and required components..."

    try {
      Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart -ErrorAction Stop | Out-Null
      Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart -ErrorAction Stop | Out-Null

      Write-Info "Installing WSL kernel update package..."
      $wslMsi = "$env:TEMP\wsl_update_x64.msi"
      Invoke-WebRequest -Uri "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi" `
        -OutFile $wslMsi -UseBasicParsing
      Start-Process msiexec.exe -ArgumentList "/i `"$wslMsi`" /quiet /norestart" -Wait

      Write-Info "Setting WSL2 as default version..."
      wsl --set-default-version 2

      # Recheck if WSL is now available
      $wslInstalled = Get-Command wsl.exe -ErrorAction SilentlyContinue
      if ($wslInstalled) {
        Write-Info "WSL installation complete."
        return $true
      }
      else {
        Write-WarningStyled "WSL installation ran but WSL.exe still not found."
        return $false
      }
    }
    catch {
      Write-ErrorStyled "WSL installation failed: $_"
      return $false
    }
  }
  else {
    Write-Info "WSL is already installed."
    return $true
  }
}
function Install-LinuxDistro {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param (
    [Parameter(Mandatory = $false)]
    [string]$DistroName = "archlinux"
  )

  # Check if already installed
  $installedDistros = wsl.exe --list --quiet
  if ($installedDistros -contains $DistroName) {
    Write-WarningStyled "$DistroName is already installed."
    return
  }

  if ($PSCmdlet.ShouldProcess("Install WSL distro '$DistroName'")) {
    Write-Info "Installing WSL distro: $DistroName..."

    try {
      wsl.exe --install $DistroName

      Write-Info "$DistroName installation triggered. This may take a few minutes..."
      Write-Info "Once the installation completes, the distro may prompt for user setup on first launch."
    }
    catch {
      Write-ErrorStyled "Failed to install ${DistroName}: $_"
    }
  }
}

function Invoke-ArchSetup {
  [CmdletBinding()]
  param ()

  # Get the path to the setup scripts inside your windots repo
  $SetupScriptPath = Join-Path (Get-ScriptRoot) "wsl/setup.sh"
  $PostInstallScriptPath = Join-Path (Get-ScriptRoot) "wsl/post-install-arch.sh"

  if (-not (Test-Path $PostInstallScriptPath)) {
    Write-ErrorStyled "Missing setup script at: $SetupScriptPath"
    return
  }

  try {
    Write-Info "Converting setup script paths to WSL paths..."

    # Use the reusable Convert-ToWSLPath function to convert both paths
    $SetupScriptPathWSL = Convert-ToWSLPath -WindowsPath $SetupScriptPath
    $PostInstallScriptPathWSL = Convert-ToWSLPath -WindowsPath $PostInstallScriptPath

    Write-Info "Converted paths: $SetupScriptPathWSL and $PostInstallScriptPathWSL"


    # Run the setup script inside WSL, then post-install script if the first one succeeds
    Write-Info "Running setup script inside WSL..."
    wsl "$SetupScriptPathWSL"
    # shut down WSL to ensure the changes take effect
    wsl --shutdown
    Start-Sleep 2

    Write-Info "Running post-install script inside WSL..."
    wsl "$PostInstallScriptPathWSL"

    Write-Info "✅ Setup completed successfully."
  }
  catch {
    Write-ErrorStyled "Failed to run setup script: $_"
  }
}

