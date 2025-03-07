param (
  $workingDirectory
)

# Version info will be inserted by install script
$scriptMajorVersion="";$scriptMinorVersion="";


$globalPrimaryScriptName = "CloneRepos"


##########################  Fix Working Directory  ################################
# If launching as admin from a .bat file it will default the working directory to system32
# so we need to pass what the working directory should be as a parameter
$currentWorkingDirectory = (Get-Item .).FullName
if ($null -ne $workingDirectory -and (-not($workingDirectory -like $currentWorkingDirectory))) {
  Write-Host -ForegroundColor Yellow "Setting working directory to '$workingDirectory'"
  Set-Location $workingDirectory
}


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


##########################  Verify Script Is NOT Running As Admin ################################
# If repos are cloned while running as administrator it causes issues adding them to github desktop
if (IsAdmin) {
  Write-Host -ForegroundColor Red "Script must NOT be run as administrator, exiting."
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


##########################  Clone Git Repositories  ################################
# (Can be run multiple times)
if ($config.settings.gitrepositories.skipsection -like "False") {
  Write-Host "Section: Clone Git Repositories (gitrepositories in config), starting..."
  $totalGitClones = $config.settings.gitrepositories.SelectNodes("./gitrepo[(@skip='False')]").count
  if ($totalGitClones -gt 0) {
    Write-Host -ForegroundColor Yellow "Clone Git Repositories..."
  }
  $currentGitClone = 0
  foreach ($gitrepo in $config.settings.gitrepositories.gitrepo) {
    if ($gitrepo.skip -like "True") {
      continue
    }
    $currentGitClone++
    $cleanedId = CleanForEnvVar -Dirty "$($gitrepo.dest)$($gitrepo.name)"
    $gitCloneEnvVarName = "NMSS_CLONEGITREPO_$($cleanedId)"
    $cloneComplete = [Environment]::GetEnvironmentVariable($gitCloneEnvVarName, 'User')
    Write-Host -ForegroundColor Yellow  "Cloning git repository ($($currentGitClone)/$($totalGitClones)) '$($gitrepo.name)' (source: '$($gitrepo.url)') from config"
    if ($cloneComplete -like "COMPLETE"){
      Write-Host -ForegroundColor Green "Clone Git Repository '$($gitrepo.name)' already completed according to environment variable. Skipping."
      continue
    }
    CloneGitRepo -URL $gitrepo.url -DestinationParentDir $gitrepo.dest -LocalName $gitrepo.name
    if ($LASTEXITCODE -eq 0) {
      Write-Host -ForegroundColor Green "$($gitrepo.name) successfully cloned."
      [Environment]::SetEnvironmentVariable($gitCloneEnvVarName, 'COMPLETE', 'User')
    }
    else {
      Write-Host -ForegroundColor Red "$($gitrepo.name) clone failed"
    }
  }
  if ($totalGitClones -gt 0){
    Write-Host -ForegroundColor Green "Finished Clone Git Repositories."
  }
  Write-Host "Section: Clone Git Repositories (gitrepositories in config), finished"
}
else {
  Write-Host "Section: Clone Git Repositories (gitrepositories in config), skipping"
}


##########################  Add Git Repositories To Github Desktop  ################################
# (Can be run multiple times)
if ($config.settings.gitrepositories.skipsection -like "False" -and $config.settings.gitrepositories.options.addrepostogithubdesktop -like "True") {
  Write-Host "Section: Add Git Repositories To Github Desktop (gitrepositories in config), starting..."
  $totalGitRepos = $config.settings.gitrepositories.SelectNodes("./gitrepo[(@skip='False')]").count
  if ($totalGitClones -gt 0){
    Write-Host -ForegroundColor Yellow "Add Git Repositories To Github Desktop..."
  }
  $currentGitRepo = 0
  foreach ($gitrepo in $config.settings.gitrepositories.gitrepo) {
    if ($gitrepo.skip -like "True") {
      continue
    }
    $currentGitRepo++
    $cleanedId = CleanForEnvVar -Dirty "$($gitrepo.dest)$($gitrepo.name)"
    $gitCloneEnvVarName = "NMSS_ADDGITREPOGHDESK_$($cleanedId)"
    $addComplete = [Environment]::GetEnvironmentVariable($gitCloneEnvVarName, 'User')
    Write-Host -ForegroundColor Yellow "Adding git repository ($($currentGitRepo)/$($totalGitRepos)) '$($gitrepo.name)' to Github Desktop"
    if ($addComplete -like "COMPLETE"){
      Write-Host -ForegroundColor Green "Clone Git Repository '$($gitrepo.name)' already completed according to environment variable. Skipping."
      continue
    }
    Write-Host "Press Enter to launch Github Desktop with the repositoy pre-filled in the Add Local Repository prompt..."
    Pause
    # Note: this does not wait on the user interacting with Github Desktop, hence the Pause...
    github "$($gitrepo.dest)$($gitrepo.name)" 
    [Environment]::SetEnvironmentVariable($gitCloneEnvVarName, 'COMPLETE', 'User')
    Write-Host -ForegroundColor Green "Git Repo '$($gitrepo.name)' Added To Github Desktop."
  }
  if ($totalGitClones -gt 0){
    Write-Host -ForegroundColor Green "Finished Add Git Repositories To Github Desktop."
  }
  Write-Host "Section: Add Git Repositories To Github Desktop (gitrepositories in config), finished"
}
else {
  Write-Host "Section: Add Git Repositories To Github Desktop (gitrepositories in config), skipping"
}


##########################  Stop Logging  ################################
if ($logStarted -like "True") {
  Stop-Transcript
}


##########################  Success Message  ################################
Write-Host -ForegroundColor Green "Execution of script $($globalPrimaryScriptName) successfully finished."
Pause