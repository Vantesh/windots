function Initialize-Dotfiles {
  [CmdletBinding()]
  param (
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\..\configs\dotfiles.json'),
    [string]$SourceRoot = (Join-Path $PSScriptRoot '..\..\dotfiles')
  )

  $homeDir = [System.Environment]::GetFolderPath('UserProfile')
  $escapedHomeDir = [Regex]::Escape($homeDir)

  if (-not (Test-Path $ConfigPath)) {
    Write-ErrorStyled "Dotfiles config not found: $ConfigPath"
    return
  }

  $dotfiles = Get-Content $ConfigPath | ConvertFrom-Json

  foreach ($entry in $dotfiles) {
    $source = Join-Path $SourceRoot $entry.source
    $target = [Environment]::ExpandEnvironmentVariables($entry.target) -replace '/', '\'

    if (-not (Test-Path $source)) {
      Write-WarningStyled "Source not found: $source"
      continue
    }

    if ($entry.type -eq 'file') {
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
    elseif ($entry.type -eq 'directory') {
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
