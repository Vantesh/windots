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

  $originalColor = $Host.UI.RawUI.ForegroundColor

  try {
    $Host.UI.RawUI.ForegroundColor = $Color
    Write-Host -NoNewline "$Prompt "
    $Host.UI.RawUI.ForegroundColor = $originalColor
    return Read-Host
  }
  finally {
    $Host.UI.RawUI.ForegroundColor = $originalColor
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
    "installing" {
      "Cyan"
    }
    "installed" {
      "Green"
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
  if ($Status -eq "installing") {
    Write-ColorText "{DarkGray}* {${sourceColor}}$label {White}$Name {Gray}$dots {${statusColor}}$Status" -NoNewLine
  }
  else {
    # Use ANSI escape sequence to clear the line more efficiently
    Write-Host "`e[2K`r" -NoNewline
    Write-ColorText "{DarkGray}* {${sourceColor}}$label {White}$Name {Gray}$dots {${statusColor}}$Status"
  }
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

function Test-WSLDistroExists {
  param (
    [string]$DistroName
  )

  return wsl.exe --list --quiet | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ -eq $DistroName.ToLower() }
}

function Convert-ToWSLPath {
  param (
    [Parameter(Mandatory = $true)]
    [string]$WindowsPath
  )

  # Convert the drive letter to lowercase and replace backslashes with forward slashes
  if ($WindowsPath -match "^([A-Za-z]):\\") {
    $DriveLetter = $matches[1].ToLower()  # Convert drive letter to lowercase
    $WSLPath = $WindowsPath -replace "^${DriveLetter}:", "/mnt/$DriveLetter" -replace '\\', '/'
  }
  else {
    # If the path does not match the expected pattern, return as is
    $WSLPath = $WindowsPath -replace '\\', '/'
  }

  return $WSLPath
}


function Test-IsInstalled {
  param (
    [string]$AppName, # Preferably the package ID (e.g., "Git.Git")
    [string]$MatchName      # Fallback name (e.g., "Git")
  )

  # Initialize cache if it doesn't exist
  if (-not (Get-Variable -Name 'InstalledAppsCache' -Scope 'Script' -ErrorAction SilentlyContinue)) {
    $script:InstalledAppsCache = @{}
  }

  # Create a cache key from the combined parameters
  $cacheKey = "$AppName|$MatchName"

  # Return cached result if available
  if ($script:InstalledAppsCache.ContainsKey($cacheKey)) {
    return $script:InstalledAppsCache[$cacheKey]
  }

  $target = if ($MatchName) {
    $MatchName
  }
  else {
    $AppName
  }

  # Fast checks first
  # 1. Winget check by ID (memory check, already cached)
  if ($global:WingetInstalledApps -and $global:WingetInstalledApps -match [regex]::Escape($AppName)) {
    $script:InstalledAppsCache[$cacheKey] = $true
    return $true
  }

  # 2. Chocolatey check (memory check, already cached)
  if ($global:ChocoInstalledApps -and $global:ChocoInstalledApps -contains $target) {
    $script:InstalledAppsCache[$cacheKey] = $true
    return $true
  }

  # 3. CLI check (in PATH?)
  if ($target -and (Get-Command $target -ErrorAction SilentlyContinue)) {
    $script:InstalledAppsCache[$cacheKey] = $true
    return $true
  }

  # 4. Registry check (most expensive, do last)
  $escTarget = [regex]::Escape($target)
  $registryPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )

  foreach ($path in $registryPaths) {
    # More efficient direct filtering
    $apps = Get-ItemProperty $path -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -and $_.DisplayName -match $escTarget }

    if ($apps) {
      $script:InstalledAppsCache[$cacheKey] = $true
      return $true
    }
  }

  # Cache the negative result as well
  $script:InstalledAppsCache[$cacheKey] = $false
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

function Backup-IfExists {
  param (
    [string]$Path,
    [string]$Suffix = (Get-Date -Format "yyyyMMdd_HHmmss")
  )
  if (Test-Path $Path) {
    $backupPath = "$Path.bak_$Suffix"
    Write-WarningStyled "Backing up existing $Path"
    Rename-Item -Path $Path -NewName $backupPath
  }
}
function Set-RegistryValue {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$Name,

    [Parameter(Mandatory)]
    [object]$Value
  )

  if (-not (Test-Path $Path)) {
    try {
      New-Item -Path $Path -Force | Out-Null
    }
    catch {
      Write-ErrorStyled "Failed to create registry path: $Path"
      return
    }
  }

  try {
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Force
  }
  catch {
    Write-ErrorStyled "Failed to set registry value: $($_.Exception.Message)"
  }
}
