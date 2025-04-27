function Set-DefaultPowerShellProfile {
  $sourceProfile = "$PSScriptRoot\..\..\dotfiles\powershell\profile.ps1"
  $userProfilePath = [System.IO.Path]::Combine($env:UserProfile, 'Documents\PowerShell\profile.ps1')

  # Create directories if missing
  New-DirectoryIfMissing -Path (Split-Path $userProfilePath)

  if (Test-Path $sourceProfile) {
    Copy-Item -Path $sourceProfile -Destination $userProfilePath -Force
    Write-Info "Copied PowerShell profile to $userProfilePath"

    # Make sure All Hosts profile is initialized
    $allHostsProfile = $PROFILE.CurrentUserAllHosts
    if ([string]::IsNullOrWhiteSpace($allHostsProfile)) {
      $allHostsProfile = [System.IO.Path]::Combine($env:UserProfile, 'Documents\PowerShell\Microsoft.PowerShell_profile.ps1')
    }

    if (-not (Test-Path $allHostsProfile)) {
      New-DirectoryIfMissing -Path (Split-Path $allHostsProfile)
      New-Item -ItemType File -Path $allHostsProfile -Force | Out-Null
      Write-Info "Created new All Hosts profile at $allHostsProfile"
    }

    Set-Content -Path $allHostsProfile -Value "`$profile = '$userProfilePath'"
    Write-Info "Set All Hosts profile to load user profile."
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

  # Fix null profile path
  $profilePath = $PROFILE.CurrentUserAllHosts
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
    [string]$ModulesJsonPath = (Join-Path $PSScriptRoot '..\..\configs\modules.json')
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
    [string]$ModulesJsonPath = (Join-Path $PSScriptRoot '..\..\configs\modules.json')
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


