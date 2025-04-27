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

function which($name) {
  Get-Command $name | Select-Object -ExpandProperty Definition
}

