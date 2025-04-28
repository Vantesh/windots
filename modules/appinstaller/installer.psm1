function Install-Choco {
  if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-TitleBox "Installing Chocolatey" -Color Cyan
    try {
      Invoke-ChocoInstallScript
      if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Info "Chocolatey installed successfully."
      }
      else {
        Write-ErrorStyled "Chocolatey installation failed."
      }
    }
    catch {
      Write-ErrorStyled "Exception occurred during Chocolatey install: $_"
    }
  }
  else {
    Write-Info "Chocolatey is already installed."
  }
}

function Invoke-ChocoInstallScript {
  # Use direct string instead of here-string for slightly better performance
  $chocoScript = 'Set-ExecutionPolicy Bypass -Scope Process -Force;' +
  '[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;' +
  'iex ((New-Object System.Net.WebClient).DownloadString(''https://community.chocolatey.org/install.ps1''))'

  # Use ScriptBlock for better performance than Invoke-Expression
  $scriptBlock = [ScriptBlock]::Create($chocoScript)
  & $scriptBlock *> $null
}

function Install-WinGetApp {
  param (
    [string]$PackageID,
    [string]$Name,
    [array]$AdditionalArgs,
    [string]$Source
  )

  # Caching the display name calculation
  $displayName = [string]::IsNullOrEmpty($Name) ? $PackageID : $Name

  # Use .NET cache to improve performance for frequently accessed packages
  $cacheKey = "$PackageID-$Name"
  if ($script:InstallStatusCache -and $script:InstallStatusCache.ContainsKey($cacheKey)) {
    return $script:InstallStatusCache[$cacheKey]
  }

  if (Test-IsInstalled -AppName $PackageID -MatchName $Name) {
    Write-InstallStatus -Source "winget" -Name $displayName -Status "exists"
    return
  }

  # Use Write-InstallStatus to show "installing"
  Write-InstallStatus -Source "winget" -Name $displayName -Status "installing"

  $argsJoined = $AdditionalArgs -join ' '
  $wingetCmd = "winget install $PackageID $argsJoined"

  if ($Source -eq "msstore") {
    $wingetCmd += " --source msstore"
  }
  else {
    $wingetCmd += " --source winget"
  }

  Invoke-Expression "$wingetCmd >`$null 2>&1"
  if ($LASTEXITCODE -eq 0) {
    Write-InstallStatus -Source "winget" -Name $displayName -Status "success"
  }
  else {
    Write-InstallStatus -Source "winget" -Name $displayName -Status "failed"
  }
}


function Install-ChocoApp {
  param ([string]$PackageName)

  if (Test-IsInstalled -AppName $PackageName) {
    Write-InstallStatus -Source "choco" -Name $PackageName -Status "exists"
    return
  }

  Write-InstallStatus -Source "choco" -Name $PackageName -Status "installing"

  choco install $PackageName -y --no-progress >$null 2>&1
  if ($LASTEXITCODE -eq 0) {
    Write-InstallStatus -Source "choco" -Name $PackageName -Status "success"
  }
  else {
    Write-InstallStatus -Source "choco" -Name $PackageName -Status "failed"
  }
}
function Invoke-AppInstallers {

  # Lazy-load slow global lookups
  if (-not $global:WingetInstalledApps) {
    $global:WingetInstalledApps = winget list 2>$null
  }
  if (-not $global:ChocoInstalledApps -and (Get-Command choco -ErrorAction SilentlyContinue)) {
    $global:ChocoInstalledApps = choco list --limit-output 2>$null | ForEach-Object { $_.Split('|')[0].Trim() }
  }

  $configPath = Join-Path (Get-ScriptRoot) "configs\applist.json"
  if (-not (Test-Path $configPath)) {
    Write-ErrorStyled "Missing applist.json in configs/"
    return
  }

  $appList = Get-Content $configPath | ConvertFrom-Json

  $defaultWingetArgs = @(
    "--exact",
    "--silent",
    "--accept-package-agreements",
    "--accept-source-agreements"
  )

  foreach ($app in $appList.winget) {
    $id = $app.packageId
    $name = $app.name
    $source = if ($app.packageSource) {
      $app.packageSource
    }
    else {
      "winget"
    }
    Install-WinGetApp -PackageID $id -Name $name -AdditionalArgs $defaultWingetArgs -Source $source
  }

  foreach ($app in $appList.choco) {
    $name = $app.packageName
    Install-ChocoApp -PackageName $name
  }
}
