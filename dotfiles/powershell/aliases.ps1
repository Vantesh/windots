# ~/.config/powershell/aliases.ps1
# ─────────────────────────────────────────────────────────────────
# Powershell Aliases
# ─────────────────────────────────────────────────────────────────
if (Get-Command lsd -ErrorAction SilentlyContinue) {
  Set-Alias ls lsd -Force
  function la {
    lsd -a
  }
  function ll {
    lsd -l

  }
  function lla {
    lsd -la
  }
  function lt {
    lsd --tree --depth=2
  }

}
# touch command
function Touch {
  [CmdletBinding()]
  param(
    [Parameter(Position = 0, Mandatory = $true, ValueFromRemainingArguments = $true)]
    [string[]]$Path,

    [Parameter()]
    [datetime]$Time = (Get-Date),

    [switch]$CreateDirectories
  )

  foreach ($p in $Path) {
    $fullPath = Resolve-Path -Path $p -ErrorAction SilentlyContinue

    if (-not $fullPath) {
      # If the path doesn't exist
      $directory = Split-Path -Parent $p

      if ($directory -and !(Test-Path $directory)) {
        if ($CreateDirectories) {
          New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        else {
          Write-Error "Directory '$directory' does not exist. Use -CreateDirectories to auto-create it."
          continue
        }
      }

      # Create an empty file
      New-Item -ItemType File -Path $p -Force | Out-Null
      $item = Get-Item -LiteralPath $p
    }
    else {
      $item = Get-Item -LiteralPath $p
    }

    # Set the LastWriteTime
    $item.LastWriteTime = $Time
    $item.LastAccessTime = $Time
  }
}



if (Get-Command bat -ErrorAction SilentlyContinue) {
  Set-Alias cat bat -Force
}

# Function to replicate "which" and pipe to bat for syntax highlighting
function which {
  param (
    [string[]]$names
  )

  # Check if 'bat' is available
  $isBatAvailable = Get-Command 'bat' -ErrorAction SilentlyContinue

  foreach ($name in $names) {
    try {
      $command = Get-Command $name -ErrorAction Stop
      if ($command.CommandType -eq 'Alias') {
        Write-Host "Alias -> $($command.Definition)"
      }
      elseif ($command.CommandType -eq 'Function') {

        if ($isBatAvailable) {
          $command.ScriptBlock | bat
        }
        else {
          $command.ScriptBlock
        }
      }
      elseif ($command.CommandType -eq 'Cmdlet' -or $command.CommandType -eq 'Application') {
        if ((Test-Path $command.Definition) -and ((Get-Item $command.Definition).Extension -match '\.(ps1|sh|bat|cmd|py|pl|rb|js|html|css|cpp|java)$')) {

          if ($isBatAvailable) {
            Get-Content $command.Definition | bat
          }
          else {
            Get-Content $command.Definition
          }
        }
        else {
          Write-Host "$($command.Definition)"
        }
      }
      else {
        Write-Host "$($command.Source)"
      }
    }
    catch {
      Write-Host "Command '$name' not found."
    }
  }
}

