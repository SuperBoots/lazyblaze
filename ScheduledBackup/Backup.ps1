$PrimaryScriptName = "Backup"
$requireAdmin = "True"
# Execute script in the current session context, variables are shared between the scripts
. ".\SharedFunctionsAndChecks.ps1"
if ($globalExit -like "True") {
  Exit
}


# For testing of this file, put it in the local config directory (default is C:\LazyBlazeConfig\) 
# and run it in an administrator powershell that's working directory is the local config directory,
# for example, run `cd C:\LazyBlazeConfig\` and then run `.\Backup.ps1`


##########################  Backup Various Config Files  ################################
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


##########################  Backup Power Settings  ################################
if ($config.settings.modifypowersettings -like "True") {
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
}


##########################  Visual Studio Install Options Export  ################################
# Note: as of recent changes (October 2024) this is no longer used.
# It failed on me one time and I switched to a more explicit config driven install.
# Keeping it around for the moment because I like the concept and might try again, 
# I like the idea that as your VS install changes over time the new state will be 
# automatically captured and backed up using this approach.
if ($config.settings.backupvscommunity -like "True"){
  Write-Host "Export Visual Studio Community installation configuration to the VisualStudio folder in the local config"
  & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe" export --quiet --force --config ".\VisualStudio\my.vsconfig" --productID Microsoft.VisualStudio.2022.Community --installPath "C:\Program Files\Microsoft Visual Studio\2022\Community"
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