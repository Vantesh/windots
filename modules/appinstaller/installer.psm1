function Install-WinGetApp {
  param (
    [string]$PackageID,
    [string]$Name,
    [array]$AdditionalArgs,
    [string]$Source
  )

  $displayName = if ($Name) { $Name } else { $PackageID }

  if (Test-IsInstalled -AppName $PackageID -MatchName $Name) {
    Write-InstallStatus -Source "winget" -Name $displayName -Status "exists"
    return
  }

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
    $source = if ($app.packageSource) { $app.packageSource } else { "winget" }
    Install-WinGetApp -PackageID $id -Name $name -AdditionalArgs $defaultWingetArgs -Source $source
  }

  foreach ($app in $appList.choco) {
    $name = $app.packageName
    Install-ChocoApp -PackageName $name
  }
}
