function Install-Office {
  $odtPath = Join-Path $env:TEMP "ODT"
  $setupUrl = "https://officecdn.microsoft.com/pr/wsus/setup.exe"
  $setupExe = Join-Path $odtPath "setup.exe"
  $configPath = Join-Path (Get-ScriptRoot) "configs\config.xml"

  # Ensure the ODT directory exists using utility
  New-DirectoryIfMissing -Path $odtPath

  # Download Office Deployment Tool if missing
  if (-not (Test-Path $setupExe)) {
    Write-Info "Downloading Office Deployment Tool..."
    try {
      Invoke-WebRequest -Uri $setupUrl -OutFile $setupExe -UseBasicParsing
    }
    catch {
      Write-ErrorStyled "Failed to download ODT: $_"
      return
    }
  }

  # Ensure config file exists
  if (-not (Test-Path $configPath)) {
    Write-ErrorStyled "Missing Office config: $configPath"
    return
  }

  # Start the Office installer
  try {
    Write-Info "Starting Office installation..."
    Start-Process -FilePath $setupExe -ArgumentList "/configure `"$configPath`"" -Wait -NoNewWindow
    Write-Info "Office installation complete."
  }
  catch {
    Write-ErrorStyled "Failed to start the Office installer: $_"
  }
}
