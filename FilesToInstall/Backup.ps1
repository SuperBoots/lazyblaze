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


##########################  Get User Specific Values From System ################################
$sysUserName = $env:USERNAME
$sysMachineName = Invoke-Expression -Command 'hostname'


##########################  Load Config  ################################
$configFullDest = ".\Config.xml"
$config = [xml](Get-Content $configFullDest)
$userFromConfig = $config.settings.username
$userdir = "C:\Users\$($userFromConfig)\"


##########################  Checking Config Version  ################################
# This section exists to protect users from running a newer version of the scripts with an older local config
# file when there have been breaking changes to the codebase. This can happen very easily if you're keeping your
# local LazyBlaze repository up to date.
$configMajorVersion = $config.settings.version.major
$configMinorVersion = $config.settings.version.minor
if (($configMajorVersion -gt $scriptMajorVersion) -or (($configMajorVersion -eq $scriptMajorVersion) -and ($configMinorVersion -gt $scriptMinorVersion))) {
  # User has somehow ende up with a local config version that's more recent than the repo that the scripts are being run from.
  Write-Host -ForegroundColor Red "You've somehow got a version of your config that's more recent than the current script. I'm going to be honest, I'm confused. I give up."
  Pause
  Exit
}
if ($configMajorVersion -lt $scriptMajorVersion) {
  # User has a local config that is old enough that the current repo has breaking changes
  Write-Host -ForegroundColor Red "ERROR: This script has a more recent major version ($($scriptMajorVersion)) than the config $($configFullDest) ($($configMajorVersion
)). Updated major versions indicate breaking changes, please bring your local config up to date before trying again."
  Pause
  Exit
}
if (($configMajorVersion -eq $scriptMajorVersion) -and ($configMinorVersion -lt $scriptMinorVersion)) {
  # User has a local config that is slightly out of date, default behavior is to block script execution but this can be overridden by the minorblocking setting in the local config.
  Write-Host -ForegroundColor Yellow "Warning: This script has a more recent minor version ($($scriptMinorVersion
)) than the config $($configFullDest) ($($configMinorVersion)). Updated minor versions indicate non-breaking changes but you may want to review the example config."
  if ($null -eq $config.settings.version.minorblocking -or $config.settings.version.minorblocking -like "True") {
    Write-Host -ForegroundColor Red "Exiting script. If you want to allow this script to continue with minor version differences set the minorblocking property to False in your local config $($configFullDest)"
    Pause
    Exit
  }
}


##########################  Verify User Has Reviewed Config  ################################
if ($config.settings.reviewed -notlike "True") {
  Write-Host -ForegroundColor Red "This script will not run until the 'reviewed' property has been set to True at the bottom of the new config file $($configDir)$($configFileName)"
  Pause
  Exit
}


##########################  Check/Populate Core Config Values  ################################
$generatedNewConfigValue = "False"
$coreConfigValueMismatch = "False"
$usernameInConfig = $config.settings.username
$actualUsername = $env:USERNAME
if ($null -eq $usernameInConfig -or $usernameInConfig -like "") {
  SetConfigValue -Key 'username' -Value $actualUsername -MyLocalConfigFile $configFullDest -OnlySetIfEmpty "True"
  Write-Host -ForegroundColor Green "Automatically setting missing value in local config, Name: username, Value: $($actualUsername)"
  $generatedNewConfigValue = "True"
}
elseif ($usernameInConfig -ne $actualUsername -and $globalRequireUserMatch -ne "False") {
  Write-Host -ForegroundColor Red "Error, username value in config does not match current user, config value: $($usernameInConfig), actual value: $($actualUsername)"
  $coreConfigValueMismatch = "True"
}
$machinenameInConfig = $config.settings.machinename
$actualMachinename = Invoke-Expression -Command 'hostname'
if ($null -eq $machinenameInConfig -or $machinenameInConfig -like "") {
  SetConfigValue -Key 'machinename' -Value $actualMachinename -MyLocalConfigFile $configFullDest -OnlySetIfEmpty "True"
  Write-Host -ForegroundColor Green "Automatically setting missing value in local config, Name: machinename, Value: $($actualMachinename)"
  $generatedNewConfigValue = "True"
}
elseif ($machinenameInConfig -ne $actualMachinename) {
  Write-Host -ForegroundColor Red "Error, machinename value in config does not match current machine name, config value: $($machinenameInConfig), actual value: $($actualMachinename)"
  $coreConfigValueMismatch = "True"
}
if ($coreConfigValueMismatch -like "True") {
  Write-Host -ForegroundColor Red "Check/Populate core config values has found at least one existing config entry that does not match the current environment. Exiting."
  Pause
  Exit
}
if ($generatedNewConfigValue -like "True") {
  Write-Host -ForegroundColor Red "Check/Populate core config values has populated at least one missing value. It is recommended that you review the populated value before running again. Exiting."
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
  $powerSettingsDir = ".\UserBackups\PowerSettings\"
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
    $vsBackupDir = ".\UserBackups\VisualStudio\"
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
if ($null -ne $config.settings.scheduledbackuptask.options.backuplogretentiondays) {
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