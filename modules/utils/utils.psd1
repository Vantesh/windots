@{
  RootModule        = 'Utils.psm1'
  ModuleVersion     = '1.0.0'
  GUID              = 'de084093-38ce-4c78-89fd-df3f718765d5'
  Author            = 'Vantesh'
  Description       = 'Reusable utility functions for system setup and configuration.'
  PowerShellVersion = '7.0'

  FunctionsToExport = @(
    'Write-TitleBox',
    'Write-ColorText',
    'Write-Info',
    'Write-WarningStyled',
    'Write-InstallStatus',
    'Write-ErrorStyled',
    'Test-IsAdmin',
    'Test-IsOnline',
    'Test-IsWSL',
    'Test-IsInstalled',
    'New-DirectoryIfMissing',
    'Get-ScriptRoot',
    'Copy-ItemWithBackup',
    'Set-SafeLink',
    'Install-Choco',
    'Install-WinGetApp'
  )

  PrivateData       = @{
    PSData = @{
      Tags       = @('PowerShell', 'Utils', 'Setup', 'Automation')
      LicenseUri = 'https://opensource.org/licenses/MIT'
      ProjectUri = 'https://github.com/Vantesh/windots'
    }
  }
}
