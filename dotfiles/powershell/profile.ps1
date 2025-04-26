# ─── Oh-My-Posh Init ──────────────────────────────────────────────
oh-my-posh init pwsh --config "$env:USERPROFILE\.config\powershell\ohmyposh\vantesh.toml" | Invoke-Expression

# ─── PSReadLine Tweaks ────────────────────────────────────────────
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineOption -PredictionSource History
Set-PSReadlineKeyHandler -Key Tab -Function Complete

# ─── Safe Module Imports ─────────────────────────────────────
if (Get-Module -ListAvailable -Name Catppuccin) {
  Import-Module Catppuccin -ErrorAction SilentlyContinue
}

if (Get-Module -ListAvailable -Name lsd-aliases) {
  Import-Module lsd-aliases -DisableNameChecking -ErrorAction SilentlyContinue
}


# ─── Catppuccin Color Setup ──────────────────────────────────
if ($Catppuccin) {
  $Flavor = $Catppuccin['Mocha']

  $Colors = @{
    ContinuationPrompt     = $Flavor.Teal.Foreground()
    Emphasis               = $Flavor.Red.Foreground()
    Selection              = $Flavor.Surface0.Background()

    InlinePrediction       = $Flavor.Overlay1.Foreground()
    ListPrediction         = $Flavor.Mauve.Foreground()
    ListPredictionSelected = $Flavor.Surface0.Background()

    Command                = $Flavor.Flamingo.Foreground()
    Comment                = $Flavor.Overlay0.Foreground()
    Default                = $Flavor.Text.Foreground()
    Error                  = $Flavor.Red.Foreground()
    Keyword                = $Flavor.Mauve.Foreground()
    Member                 = $Flavor.Rosewater.Foreground()
    Number                 = $Flavor.Peach.Foreground()
    Operator               = $Flavor.Sky.Foreground()
    Parameter              = $Flavor.Pink.Foreground()
    String                 = $Flavor.Green.Foreground()
    Type                   = $Flavor.Yellow.Foreground()
    Variable               = $Flavor.Lavender.Foreground()
  }

  # PS formatting styles (PS 7.2+)
  $versionMinimum = [version]"7.2.0"
  if ($PSVersionTable.PSVersion -ge $versionMinimum) {
    $PSStyle.Formatting.Debug = $Flavor.Sky.Foreground()
    $PSStyle.Formatting.Error = $Flavor.Red.Foreground()
    $PSStyle.Formatting.ErrorAccent = $Flavor.Blue.Foreground()
    $PSStyle.Formatting.FormatAccent = $Flavor.Teal.Foreground()
    $PSStyle.Formatting.TableHeader = $Flavor.Rosewater.Foreground()
    $PSStyle.Formatting.Verbose = $Flavor.Yellow.Foreground()
    $PSStyle.Formatting.Warning = $Flavor.Peach.Foreground()

  }
  Set-PSReadLineOption -Colors $Colors
}
# ─── LS_COLORS Setup ────────────────────────────────────────────
$lscolorsPath = "$env:USERPROFILE\.config\lscolors\lscolors"
if (Test-Path $lscolorsPath) {
  $env:LS_COLORS = (Get-Content $lscolorsPath -Raw).Trim()
}
# ─── Aliases ──────────────────────────────────────────────
$aliasFile = "$env:USERPROFILE\.config\powershell\aliases.ps1"
if (Test-Path $aliasFile) {
  . $aliasFile
}
# ─── Zoxide Init ──────────────────────────────────────────────
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
}
