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

  # Backup the .config folder (if exists)
  $configFolder = Join-Path $homeDir ".config"
  if (Test-Path $configFolder -PathType Container) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupConfigFolder = "$configFolder.bak_$timestamp"
    Write-WarningStyled "Backing up .config folder"
    Rename-Item -Path $configFolder -NewName $backupConfigFolder
  }

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
      $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
      $backupTarget = "$target.bak_$timestamp"

      if (Test-Path $target) {
        Write-WarningStyled "Backing up existing $target"
        Rename-Item -Path $target -NewName $backupTarget
      }
    }

    # Copy file or directory based on type
    if ($entryType -eq 'file') {
      $targetDir = Split-Path $target -Parent
      if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
      }

      Copy-Item -Path $source -Destination $target -Force

      $relativePath = $target -replace "^$escapedHomeDir", '~'

      # Compress AppData path for easier readability
      $relativePath = $relativePath -replace '\\AppData\\Local\\[^\\]+\\[^\\]+', '\\AppData\\...'

      Write-Info "Copied file → $relativePath"
    }
    elseif ($entryType -eq 'directory') {
      if (Test-Path $target -PathType Leaf) {
        Remove-Item -Path $target -Force
      }
      if (-not (Test-Path $target)) {
        New-Item -ItemType Directory -Path $target -Force | Out-Null
      }

      Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force

      $relativePath = $target -replace "^$escapedHomeDir", '~'

      # Compress AppData path for easier readability
      $relativePath = $relativePath -replace '\\AppData\\Local\\[^\\]+\\[^\\]+', '\\AppData\\...'

      Write-Info "Copied directory → $relativePath"
    }
    else {
      Write-WarningStyled "Unknown type '$($entry.type)' for $source"
    }
  }

  Write-Info "Dotfiles setup complete"
}
