
function Rename-PC {
  [CmdletBinding()]
  param ()

  $newName = Read-ColoredInput "Enter new PC name"

  if (-not $newName -or $newName.Length -gt 15 -or $newName -notmatch '^[a-zA-Z0-9-]+$') {
    Write-ErrorStyled "Invalid name. Must be ≤15 chars, alphanumeric or hyphens only."
    return
  }

  try {
    Rename-Computer -NewName $newName -Force -ErrorAction Stop
    Write-Info "PC renamed to '$newName'. A restart is required for changes to apply." -ForegroundColor Green
  }
  catch {
    Write-ErrorStyled "Failed to rename PC: $_"
  }
}

function Set-CustomRegionalFormat {
  [CmdletBinding()]
  param ()

  $regPath = "HKCU:\Control Panel\International"
  Write-Host "[*] Applying custom regional format..." -ForegroundColor Cyan

  @{
    iFirstDayOfWeek = "0"
    sShortDate      = "d/M/yyyy"
    sLongDate       = "dddd, d MMMM, yyyy"
    sShortTime      = "HH:mm"
    sTimeFormat     = "HH:mm:ss"
  }.GetEnumerator() | ForEach-Object {
    Set-RegistryValue -Path $regPath -Name $_.Key -Value $_.Value
  }

  $tzUrl = 'https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/default-time-zones'
  $hyperlink = "`e]8;;$tzUrl`e\here`e]8;;`e\"
  Write-Host "💡 Hint: Use a valid Windows time zone ID (e.g., 'E. Africa Standard Time'). Full list $hyperlink." -ForegroundColor DarkGray

  $timeZone = Read-ColoredInput "TimeZone"
  if ([string]::IsNullOrWhiteSpace($timeZone)) {
    $timeZone = "E. Africa Standard Time"
    Write-Host "[~] No input. Defaulting to Nairobi (E. Africa Standard Time)" -ForegroundColor Cyan
  }

  try {
    tzutil /s "$timeZone"
    Write-Info "Timezone set to: $timeZone"
  }
  catch {
    Write-ErrorStyled "Failed to set timezone: $($_.Exception.Message)"
  }
}

function Set-FileExplorerTweaks {
  [CmdletBinding()]
  param ()

  $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"
  $advancedPath = "$regPath\Advanced"

  $settings = @{
    "$regPath"      = @{ ShowRecent = 0; ShowFrequent = 0 }
    "$advancedPath" = @{
      Start_TrackDocs = 0
      AutoCheckSelect = 1
      HideFileExt     = 0
      LaunchTo        = 1
    }
  }

  foreach ($path in $settings.Keys) {
    foreach ($name in $settings[$path].Keys) {
      Set-RegistryValue -Path $path -Name $name -Value $settings[$path][$name]
    }
  }

  Write-Info "File Explorer tweaks applied (This PC set as default)." -ForegroundColor Green
}

function Enable-WindowsDarkMode {
  [CmdletBinding()]
  param ()

  Write-Host "[*] Enabling Windows dark mode for system and apps..." -ForegroundColor Cyan

  $personalizePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

  try {
    Set-RegistryValue -Path $personalizePath -Name "AppsUseLightTheme" -Value 0
    Set-RegistryValue -Path $personalizePath -Name "SystemUsesLightTheme" -Value 0
    Write-Info "Dark mode enabled. Might require a logoff or restart to fully apply." -ForegroundColor Green
  }
  catch {
    Write-Host "[X] Failed to enable dark mode: $($_.Exception.Message)" -ForegroundColor Red
  }
}

function Set-TaskbarAndSearchUI {
  [CmdletBinding()]
  param ()

  Write-Host "[*] Tweaking taskbar and search UI..." -ForegroundColor Cyan

  try {
    # Search icon only
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 1

    # Hide Task View
    Set-RegistryValue -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowTaskViewButton" -Value 0

    # Disable web results in Start menu
    Set-RegistryValue -Path "HKCU:\Software\Policies\Microsoft\Windows\Explorer" -Name "DisableSearchBoxSuggestions" -Value 1

    Write-Info "Taskbar and Start menu tweaks applied."
  }
  catch {
    Write-ErrorStyled "Failed to apply taskbar tweaks: $($_.Exception.Message)"
  }
}

function Remove-Bloatware {
  [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
  param (
    [string]$JsonPath = (Join-Path (Get-ScriptRoot) 'configs/applist.json'),
    [switch]$AllUsers
  )

  if (-not (Test-Path $JsonPath)) {
    Write-ErrorStyled "Bloatware config not found: $JsonPath"
    return
  }

  $json = Get-Content $JsonPath -Raw | ConvertFrom-Json
  $bloatware = $json.bloatware
  if (-not $bloatware) {
    Write-WarningStyled "No bloatware patterns found in config."
    return
  }

  foreach ($patternRaw in $bloatware) {
    $pattern = $patternRaw.Trim()
    $matched = $false

    # Appx Packages
    $appxPackages = if ($AllUsers) {
      Get-AppxPackage -AllUsers -PackageTypeFilter Bundle | Where-Object {
        $_.Name -like $pattern -or $_.PackageFullName -like $pattern -or $_.PackageFamilyName -like $pattern
      }
    }
    else {
      Get-AppxPackage -PackageTypeFilter Bundle | Where-Object {
        $_.Name -like $pattern -or $_.PackageFullName -like $pattern -or $_.PackageFamilyName -like $pattern
      }
    }

    if ($appxPackages) {
      $matched = $true
      foreach ($app in $appxPackages) {
        if ($PSCmdlet.ShouldProcess("Appx package: $($app.Name)", "Remove-AppxPackage")) {
          try {
            if ($AllUsers) {
              Remove-AppxPackage -Package $app.PackageFullName -AllUsers -ErrorAction Stop
            }
            else {
              Remove-AppxPackage -Package $app.PackageFullName -ErrorAction Stop
            }
            Write-Info "Removed Appx: $($app.Name)"
          }
          catch {
            Write-ErrorStyled "Failed to remove $($app.Name): $_"
          }
        }
      }
    }

    # Provisioned Packages
    $provisioned = Get-AppxProvisionedPackage -Online | Where-Object {
      $_.DisplayName -like $pattern
    }

    if ($provisioned) {
      $matched = $true
      foreach ($prov in $provisioned) {
        if ($PSCmdlet.ShouldProcess("Provisioned package: $($prov.DisplayName)", "Remove-AppxProvisionedPackage")) {
          try {
            Remove-AppxProvisionedPackage -Online -PackageName $prov.PackageName -ErrorAction Stop
            Write-Info "Removed provisioned: $($prov.DisplayName)"
          }
          catch {
            Write-ErrorStyled "Failed to remove provisioned $($prov.DisplayName): $_"
          }
        }
      }
    }

    # Winget Fallback (handling wildcards)
    if (-not $matched) {
      try {
        # Replace * wildcard with .*, which is compatible with regex
        $wingetPattern = $pattern -replace '\*', '.*'

        # Check if Winget has a match for the package
        $wingetList = winget list --accept-source-agreements | Where-Object { $_ -match "(?i)$wingetPattern" }

        if ($wingetList) {
          if ($PSCmdlet.ShouldProcess("Winget package: $pattern", "winget uninstall")) {
            $quoted = '"' + $pattern + '"'
            $wingetArgs = @("uninstall", $quoted, "--silent", "--accept-source-agreements")
            Start-Process -FilePath "winget" -ArgumentList $wingetArgs -WindowStyle Hidden -Wait


            Write-Info "Removed via winget: $pattern"
            $matched = $true
          }
        }
      }
      catch {
        Write-WarningStyled "Winget failed for '$pattern': $_"
      }
    }

    if (-not $matched) {
      Write-WarningStyled "No match for '$pattern'"
    }
  }
}


function Set-WindowsCustomizations {
  [CmdletBinding()]
  param ()

  Write-Host "[*] Applying all Windows customizations..." -ForegroundColor Magenta
  Rename-PC
  Set-CustomRegionalFormat
  Set-FileExplorerTweaks
  Enable-WindowsDarkMode
  Set-TaskbarAndSearchUI

  Write-Host "[*] Restarting File Explorer to apply changes..." -ForegroundColor Cyan
  try {
    Stop-Process -Name explorer -Force
    Start-Process explorer.exe
    Write-Info "File Explorer restarted."
  }
  catch {
    Write-ErrorStyled "Failed to restart File Explorer: $($_.Exception.Message)"
  }

  Write-Info "All Windows customizations applied."
}
