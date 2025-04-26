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

}
if (Get-Command bat -ErrorAction SilentlyContinue) {
  Set-Alias cat bat -Force
}

function which($name) {
  Get-Command $name | Select-Object -ExpandProperty Definition
}

