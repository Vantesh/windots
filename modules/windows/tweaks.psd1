@{
  RootModule        = 'tweaks.psm1'
  ModuleVersion     = '1.0.0'
  Author            = 'Vantesh'
  PowerShellVersion = '7.0'
  Description       = 'Windows-specific functions for system setup and configuration'
  FunctionsToExport = @(
    'Rename-PC',
    'Set-CustomRegionalFormat',
    'Set-FileExplorerTweaks',
    'Enable-WindowsDarkMode',
    'Set-WindowsCustomizations'
  )
}
