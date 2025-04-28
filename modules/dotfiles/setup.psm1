function Initialize-Dotfiles {
  [CmdletBinding()]
  param (
    [string]$ConfigPath = (Join-Path (Get-ScriptRoot) "/configs/dotfiles.json"),
    [string]$SourceRoot = (Join-Path (Get-ScriptRoot) "/dotfiles/")
  )
  # Expand environment variables in ConfigPath and SourceRoot
  $ConfigPath = [System.Environment]::ExpandEnvironmentVariables($ConfigPath)
  $SourceRoot = [System.Environment]::ExpandEnvironmentVariables($SourceRoot)

  $homeDir = [System.Environment]::GetFolderPath('UserProfile')
  $escapedHomeDir = [Regex]::Escape($homeDir)

  # Check if config file exists
  if (-not (Test-Path $ConfigPath)) {
    Write-ErrorStyled "Dotfiles config not found: $ConfigPath"
    return
  }

  $dotfiles = Get-Content $ConfigPath | ConvertFrom-Json


  function Compress-Path {
    param (
      [string]$Path,
      [string]$HomeDir
    )
    $escapedHomeDir = [Regex]::Escape($HomeDir)
    $relativePath = $Path -replace "^$escapedHomeDir", '~'
    return $relativePath -replace '\\AppData\\Local\\[^\\]+\\[^\\]+', '\\AppData\\...'
  }

  # Backup the .config folder (if exists)
  Backup-IfExists -Path (Join-Path $homeDir ".config")

  foreach ($entry in $dotfiles) {
    # Expand environment variables in source and target paths
    $source = Join-Path $SourceRoot $entry.source
    $target = [System.Environment]::ExpandEnvironmentVariables($entry.target) -replace '/', '\'

    if (-not (Test-Path $source)) {
      Write-WarningStyled "Source not found: $source"
      continue
    }

    # Ensure type is correctly defined and valid
    $entryType = if ($entry.type -in @('file', 'directory')) {
      $entry.type
    }
    else {
      Write-WarningStyled "Unknown or missing type for $source, defaulting to 'file'"
      $entryType = 'file'
    }

    # Handle backup of .gitconfig file
    if ($target -eq "$homeDir\.gitconfig") {
      Backup-IfExists -Path $target
    }

    # Copy file or directory based on type
    if ($entryType -eq 'file') {
      $targetDir = Split-Path $target -Parent
      if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
      }

      Copy-Item -Path $source -Destination $target -Force
      $relativePath = Compress-Path -Path $target -HomeDir $homeDir

      # Special check to distinguish between winget and terminal settings.json
      if ($entry.source -eq 'winget/settings.json') {
        Write-Info "Copied Winget settings.json from → $relativePath"
      }
      elseif ($entry.source -eq 'terminal/settings.json') {
        Write-Info "Copied Terminal settings.json → $relativePath"
      }
      else {
        Write-Info "Copied file → $relativePath"
      }
    }
    elseif ($entryType -eq 'directory') {
      if (Test-Path $target -PathType Leaf) {
        Remove-Item -Path $target -Force
      }
      if (-not (Test-Path $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
      }

      Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
      $relativePath = Compress-Path -Path $target -HomeDir $homeDir

      Write-Info "Copied directory → $relativePath"
    }
    else {
      Write-WarningStyled "Unknown type '$($entry.type)' for $source"
    }
  }

  Write-Info "Dotfiles setup complete"
}
