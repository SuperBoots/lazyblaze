# Version info will be inserted by install script
$scriptMajorVersion="";$scriptMinorVersion="";

$globalPrimaryScriptName = "Backup"
$globalRequireAdmin = "True"
$globalRequireUserMatch = "False"


##########################  Start Logging  ################################
$date = (Get-Date).ToString("yyyy-MM-dd_HHmmss")
$logFile = ".\Logs\$($date)_$($globalPrimaryScriptName)_log.txt"
Start-Transcript -Path $logFile
$logStarted = "True"


##########################  Import Custom Powershell Modules ################################
Import-Module ".\LazyBlazeScripts\PowershellModules\BackupConfigFile.psm1"
Import-Module ".\LazyBlazeScripts\PowershellModules\CleanForEnvVar.psm1"
Import-Module ".\LazyBlazeScripts\PowershellModules\CloneGitRepo.psm1"
Import-Module ".\LazyBlazeScripts\PowershellModules\DeleteDirectory.psm1"
Import-Module ".\LazyBlazeScripts\PowershellModules\ExcludeFromBackblaze.psm1"
Import-Module ".\LazyBlazeScripts\PowershellModules\IsAdmin.psm1"
Import-Module ".\LazyBlazeScripts\PowershellModules\MoveShortcuts.psm1"
Import-Module ".\LazyBlazeScripts\PowershellModules\PopulateConfigFile.psm1"
Import-Module ".\LazyBlazeScripts\PowershellModules\RemoveBrokenShortcuts.psm1"
Import-Module ".\LazyBlazeScripts\PowershellModules\ReplaceLine.psm1"
Import-Module ".\LazyBlazeScripts\PowershellModules\SetConfigValue.psm1"


##########################  Verify Script Is Running As Admin ################################
if (-not (IsAdmin)) {
  Write-Host -ForegroundColor Red "Script must be run as administrator, exiting."
  Pause
  Exit
}


# For testing of this file, put it in the local config directory (default is C:\LazyBlazeConfig\) 
# and run it in an administrator powershell that's working directory is the local config directory,
# for example, run `cd C:\LazyBlazeConfig\` and then run `.\Backup.ps1`


##########################  Backup Various Config Files  ################################
if ($config.settings.appdatabackups.skipsection -like "False") {
  Write-Host "Section: Backup Various Config Files (appdatabackups in config), starting..."
  foreach ($backup in $config.settings.appdatabackups.backup) {
    if ($backup.skip -like "True") {
      continue
    }
    else {
      Write-Host "Backing up $($backup.filename) from config"
      if ($config.settings.displaydescriptions -like "True" -and $backup.description -ne $null) {
        Write-Host $backup.description
      }
      BackupConfigFile -FileName $backup.filename -SourceDir "$($userdir)$($backup.appdatadir)" -TargetDir ".\$($backup.configfolder)\"
    }
  }
  Write-Host "Section: Backup Various Config Files (appdatabackups in config), finished"
}
else {
  Write-Host "Section: Backup Various Config Files (appdatabackups in config), skipping"
}


##########################  Backup Power Settings  ################################
if ($config.settings.powersettings.skipsection -like "False") {
  Write-Host "Section: Backup Power Settings (powersettings in config), starting..."
  $powerSettingsDir = ".\PowerSettings\"
  $powerSettingsFile = "$($powerSettingsDir)myscheme.pow"
  If (test-path -PathType leaf $powerSettingsFile){
    Remove-Item -LiteralPath $powerSettingsFile
  }
  if (!(Test-Path -LiteralPath $powerSettingsDir)) {
    New-Item -ItemType Directory -Path $powerSettingsDir
  }
  $currentSchemeGuid = [regex]::Match((POWERCFG /GETACTIVESCHEME), 'GUID: ([\w-]+)').Groups[1].Value
  POWERCFG /EXPORT $powerSettingsFile $currentSchemeGuid
  Write-Host "Section: Backup Power Settings (powersettings in config), finished"
}
else {
  Write-Host "Section: Backup Power Settings (powersettings in config), skipping"
}


##########################  Visual Studio Install Options Export  ################################
# Note: as of recent changes (October 2024) this is no longer used.
# It failed on me one time and I switched to a more explicit config driven install.
# Keeping it around for the moment because I like the concept and might try again, 
# I like the idea that as your VS install changes over time the new state will be 
# automatically captured and backed up using this approach.
if ($config.settings.visualstudio.skipsection -like "False" -and $config.settings.visualstudio.options.savesnapshots -like "True"){
  Write-Host "Section: Visual Studio Install Options Export (visualstudio in config), starting..."
  try {
    Write-Host "Export Visual Studio Community installation configuration to the VisualStudio folder in the local config"
    $vsBackupDir = "$($configDir)VisualStudio\"
    if (-not (Test-Path -LiteralPath $vsBackupDir)) {
      New-Item -ItemType Directory -Path $vsBackupDir
    }
    & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe" export --quiet --force --config "$($vsBackupDir)my.vsconfig" --productID Microsoft.VisualStudio.2022.Community --installPath "C:\Program Files\Microsoft Visual Studio\2022\Community"
  if ($LASTEXITCODE -eq 0) {
    Write-Host "Export Visual Studio Community installation configuration completed successfully."
  }
  else {
    Write-Host "Export Visual Studio Community installation configuration failed"
  }
  }
  catch [System.Exception] {
    $_ # Output the current value in the pipe, in this case the exception details
    Write-Host "Export Visual Studio Community installation configuration failed"
  }
  Write-Host "Section: Visual Studio Install Options Export (visualstudio in config), finished"
}
else {
  Write-Host "Section: Visual Studio Install Options Export (visualstudio in config), skipping"
}

##########################  Delete Old Log Files  ################################
if ($null -ne $config.settings.backuplogretentiondays) {
  Write-Host "Cleaning old backup process log files"
  $limit = (Get-Date).AddDays(-$($config.settings.backuplogretentiondays))
  Get-ChildItem ".\Logs" | Where-Object{$_.Name -Match ".*(_Backup_log.txt)" -and !$_.PSIsContainer -and $_.CreationTime -lt $limit} | Remove-Item
}
else {
  Write-Host "Cannot find backuplogretentiondays config setting, skipping log file cleanup"
}

if ($logStarted -like "True") {
  Stop-Transcript
}