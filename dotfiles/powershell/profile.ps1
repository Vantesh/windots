$env:XDG_CONFIG_HOME = "$env:USERPROFILE\.config"

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
  $Flavor = $Catppuccin['Macchiato']

  $Colors = @{
    ContinuationPrompt     = $Flavor.Teal.Foreground()
    Emphasis               = $Flavor.Red.Foreground()
    Selection              = $Flavor.Surface0.Background()

    InlinePrediction       = $Flavor.Overlay1.Foreground()
    ListPrediction         = $Flavor.Mauve.Foreground()
    ListPredictionSelected = $Flavor.Surface0.Background()

    Command                = $Flavor.Flamingo.Foreground()
    Comment                = $Flavor.Overlay1.Foreground()
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
if (Get-Command fzf -ErrorAction SilentlyContinue) {
  $ENV:FZF_DEFAULT_OPTS = @"
 --color=fg:#cdd6f4,fg+:#d0d0d0,bg:#1e1e2e,bg+:#262626
  --color=hl:#f38ba8,hl+:#5fd7ff,info:#cba6f7,marker:#b4befe
  --color=prompt:#cba6f7,spinner:#f5e0dc,pointer:#f5e0dc,header:#f38ba8
  --color=gutter:#1e1e2e,border:#313244,label:#cdd6f4,query:#d9d9d9
  --border="rounded" --border-label="" --preview-window="border-rounded"
  --marker=" " --pointer="◆" --separator="" --scrollbar=""
  --layout="reverse"
  --height=40%
"@
  function ff {
    fzf --preview 'bat --style=numbers --color=always --line-range :500 {}'
  }

}
if (Get-Command bat -ErrorAction SilentlyContinue) {
  $env:BAT_CONFIG_DIR = "$env:USERPROFILE\.config\bat"
  $env:BAT_CONFIG_PATH = "$env:BAT_CONFIG_DIR\config.conf"
}

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
if (Get-Command choco -ErrorAction SilentlyContinue) {
  $ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
  Import-Module "$ChocolateyProfile" -Global
}

# ─── Zoxide Init ──────────────────────────────────────────────
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
  Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
}
