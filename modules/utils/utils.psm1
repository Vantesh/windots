function Write-TitleBox {
  param (
    [string]$Text,
    [string]$Color = "White"  # Default color for title text
  )

  $emoji = "🛠️"
  $padded = "$emoji  $Text  $emoji"
  $border = "─" * $padded.Length

  Write-Host "`n$border" -ForegroundColor Yellow
  Write-Host $padded -ForegroundColor $Color
  Write-Host $border -ForegroundColor Yellow
}



function Write-ColorText {
  param (
    [string]$Text,
    [switch]$NoNewLine
  )

  $defaultColor = $Host.UI.RawUI.ForegroundColor
  $lines = $Text -split "`n"

  foreach ($line in $lines) {
    $index = 0

    [regex]::Matches($line, '(\{([a-zA-Z]+)\}(.*?))(?=\{[a-zA-Z]+\}|$)') | ForEach-Object {
      $match = $_

      if ($match.Index -gt $index) {
        $raw = $line.Substring($index, $match.Index - $index)
        Write-Host -NoNewline $raw -ForegroundColor $defaultColor
      }

      $color = $match.Groups[2].Value
      $content = $match.Groups[3].Value
      Write-Host -NoNewline $content -ForegroundColor $color
      $index = $match.Index + $match.Length
    }

    if ($index -lt $line.Length) {
      $remainder = $line.Substring($index)
      Write-Host -NoNewline $remainder -ForegroundColor $defaultColor
    }

    if (-not $NoNewLine) {
      Write-Host ""
    }
  }

  $Host.UI.RawUI.ForegroundColor = $defaultColor
}
function Read-ColoredInput {
  param (
    [Parameter(Mandatory)]
    [string]$Prompt,

    [string]$Color = 'Cyan'
  )

  $originalColor = [Console]::ForegroundColor

  try {
    # Set prompt color
    [Console]::ForegroundColor = $Color
    Write-Host -NoNewline $Prompt
    # Reset to original color
    [Console]::ForegroundColor = $originalColor
    return Read-Host
  }
  finally {
    [Console]::ForegroundColor = $originalColor
  }
}


function Write-Info {
  param ([string]$Message)
  Write-ColorText "[{Green}✔{White}] {white}$Message"
}

function Write-WarningStyled {
  param ([string]$Message)
  Write-ColorText "[{Yellow}!{White}] {Yellow}$Message"
}

function Write-ErrorStyled {
  param ([string]$Message)
  Write-ColorText "[{Red}X{White}] {Red}$Message"
}
function Write-InstallStatus {
  param (
    [string]$Source,
    [string]$Name,
    [string]$Status
  )

  $sourceColor = switch ($Source.ToLower()) {
    "winget" {
      "Magenta"
    }
    "choco" {
      "Cyan"
    }
    default {
      "Gray"
    }
  }

  $statusColor = switch ($Status.ToLower()) {
    "exists" {
      "Yellow"
    }
    "success" {
      "Green"
    }
    "failed" {
      "Red"
    }
    default {
      "Gray"
    }
  }

  $label = $Source.PadRight(7)
  $dots = "-" * ([Math]::Max(1, 42 - $Name.Length))

  Write-ColorText "{DarkGray}* {${sourceColor}}$label {White}$Name {Gray}$dots {${statusColor}}$Status"
}
function Test-IsValidEmail {
  param (
    [string]$Email
  )

  # Updated regex to allow GitHub noreply emails and legit domains
  return $Email -match '^[\w\.\+\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$'
}

function Test-IsAdmin {
  $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Test-IsOnline {
  try {
    $ping = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction Stop
    return $ping
  }
  catch {
    return $false
  }
}

function Test-IsWSL {
  return $null -ne $env:WSL_DISTRO_NAME
}

function Test-IsInstalled {
  param (
    [string]$AppName, # Preferably the package ID (e.g., "Git.Git")
    [string]$MatchName      # Fallback name (e.g., "Git")
  )

  $target = if ($MatchName) {
    $MatchName
  }
  else {
    $AppName
  }

  # Winget check by ID
  if ($global:WingetInstalledApps -and $global:WingetInstalledApps -match [regex]::Escape($AppName)) {
    return $true
  }

  # CLI check (in PATH?)
  if (Get-Command $target -ErrorAction SilentlyContinue) {
    return $true
  }
  # Chocolatey check
  if ($global:ChocoInstalledApps -and $global:ChocoInstalledApps -contains $target) {
    return $true
  }

  # 4. Registry check
  $registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )
  foreach ($path in $registryPaths) {
    $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue
    if ($apps.DisplayName -like "*$target*") {
      return $true
    }
  }

  return $false
}



function New-DirectoryIfMissing {
  param ([string]$Path)

  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Write-Info "Created path: $Path"
  }
}

function Get-ScriptRoot {
  if ($MyInvocation.MyCommand.Path) {
    return Split-Path -Parent $MyInvocation.MyCommand.Path
  }
  else {
    return (Get-Location).Path
  }
}


function Copy-ItemWithBackup {
  param (
    [string]$Target,
    [string]$Source
  )

  if (Test-Path $Target) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backup = "$Target.bak_$timestamp"
    Rename-Item -Path $Target -NewName $backup
    Write-WarningStyled "Backed up existing file: $Target -> $backup"
  }

  Copy-Item -Path $Source -Destination $Target -Force
  Write-Info "Replaced $Target with $Source"
}

function Set-SafeLink {
  param (
    [string]$Source,
    [string]$Target
  )

  try {
    New-Item -ItemType SymbolicLink -Path $Target -Target $Source -Force
    Write-Info "Symlinked $Target -> $Source"
  }
  catch {
    Copy-Item -Path $Source -Destination $Target -Recurse -Force
    Write-WarningStyled "Symlink failed, copied instead: $Source -> $Target"
  }
}


function Install-Choco {
  if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-TitleBox "Installing Choco"
    Set-ExecutionPolicy Bypass -Scope Process -Force

    try {
      $chocoScript = "Set-ExecutionPolicy Bypass -Scope Process -Force; `
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"

      Invoke-Expression $chocoScript

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
