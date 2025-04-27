function Set-ProfileForAllHosts {
  # Define source profile and the target location for All Hosts profile
  $sourceProfile = Join-Path (Get-ScriptRoot) ".\dotfiles\powershell\profile.ps1"
  $allHostsProfilePath = [System.IO.Path]::Combine($env:UserProfile, 'Documents\PowerShell\profile.ps1')

  if (Test-Path $sourceProfile) {
    # Create the directory if it doesn't exist
    New-DirectoryIfMissing -Path (Split-Path $allHostsProfilePath)

    # Copy the source profile to the All Hosts profile path
    Copy-Item -Path $sourceProfile -Destination $allHostsProfilePath -Force
    Write-Info "Copied PowerShell profile to $allHostsProfilePath"

  }
  else {
    Write-ErrorStyled "Source profile file not found: $sourceProfile"
  }
}


function Add-ModuleToProfile {
  param (
    [Parameter(Mandatory)][string]$ModuleName,
    [switch]$SuppressDuplicates,
    [switch]$DisableNameChecking
  )
  $profilePath = [System.IO.Path]::Combine($env:UserProfile, 'Documents\PowerShell\profile.ps1')
  if ([string]::IsNullOrWhiteSpace($profilePath)) {
    $profilePath = [System.IO.Path]::Combine($env:UserProfile, 'Documents\PowerShell\profile.ps1')
  }

  $importLine = "Import-Module $ModuleName" + ($DisableNameChecking.IsPresent ? " -DisableNameChecking" : "")

  if (-not (Test-Path $profilePath)) {
    New-DirectoryIfMissing -Path (Split-Path $profilePath)
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
    Write-Info "Created new profile at $profilePath"
  }

  $content = Get-Content $profilePath -Raw
  if ($content -notmatch [regex]::Escape($importLine)) {
    Set-Content $profilePath -Value "$importLine`n$content" -Force
    Write-Info "Added Import-Module for '$ModuleName' to profile."
  }
  elseif (-not $SuppressDuplicates) {
    Write-Info "Import for '$ModuleName' already exists."
  }
}

function Install-ModulesFromJson {
  param (
    [string]$ModulesJsonPath = (Join-Path (Get-ScriptRoot) ".\configs\modules.json")
  )

  if (-not (Test-Path $ModulesJsonPath)) {
    Write-ErrorStyled "Modules JSON not found: $ModulesJsonPath"
    return
  }

  $modules = Get-Content $ModulesJsonPath | ConvertFrom-Json

  foreach ($module in $modules) {
    $name = $module.name

    if (-not (Get-Module -ListAvailable -Name $name)) {
      try {
        Write-Info "Installing module: $name"
        Install-Module -Name $name -Force -Confirm:$false -ErrorAction Stop
        Write-Info "Installed module: $name"
      }
      catch {
        Write-ErrorStyled "Failed to install '$name': $_"
      }
    }
    else {
      Write-Info "Module '$name' already installed."
    }
  }
}

function Import-ModulesFromJson {
  param (
    [string]$ModulesJsonPath = (Join-Path (Get-ScriptRoot) ".\configs\modules.json")
  )

  if (-not (Test-Path $ModulesJsonPath)) {
    Write-ErrorStyled "Modules JSON not found: $ModulesJsonPath"
    return
  }

  $modules = Get-Content $ModulesJsonPath | ConvertFrom-Json

  foreach ($module in $modules) {
    $name = $module.name
    $requiresImport = $module.requiresImport
    $disableNameChecking = $module.disableNameChecking

    if ($requiresImport) {
      Add-ModuleToProfile -ModuleName $name -DisableNameChecking:$disableNameChecking
    }
    else {
      Write-Info "Skipping import for module '$name'"
    }
  }
}

function Install-CatppuccinTheme {
  $repoUrl = "https://github.com/catppuccin/powershell.git"
  $tempPath = Join-Path $env:TEMP "catppuccin_tmp"
  $moduleName = "Catppuccin"
  $installPath = Join-Path (($env:PSModulePath -split ";") | Where-Object { $_ -like "*Documents*" }) $moduleName

  if (Test-Path $tempPath) {
    Remove-Item -Path $tempPath -Recurse -Force
  }

  Write-Info "Cloning Catppuccin theme..."
  git clone --quiet --depth 1 $repoUrl $tempPath

  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tempPath)) {
    Write-ErrorStyled "Failed to clone Catppuccin repo."
    return
  }

  Remove-Item -Path (Join-Path $tempPath ".git") -Recurse -Force

  if (Test-Path $installPath) {
    Remove-Item -Path $installPath -Recurse -Force
  }

  Move-Item -Path $tempPath -Destination $installPath

  if (Test-Path $installPath) {
    Add-ModuleToProfile -ModuleName $moduleName -SuppressDuplicates
    Write-Info "Installed Catppuccin theme successfully!"
  }
  else {
    Write-ErrorStyled "Failed to move Catppuccin theme to $installPath"
  }
}


