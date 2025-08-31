param (
  $workingDirectory
)

# Version info will be inserted by install script
$scriptMajorVersion="";$scriptMinorVersion="";
  
$globalPrimaryScriptName = "Main"

  
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


##########################  Remove Bloatware  ################################
# (Can be run multiple times)
if ($config.settings.bloatwareremoval.skipsection -like "False") {
  Write-Host "Section: Remove Bloatware (bloatwareremoval in config), starting..."
  $totalBloatwareRemovals = $config.settings.bloatwareremoval.SelectNodes("./bloatware[(@skip='False')]").count
  $currentBloatwareRemoval = 0
  if ($totalBloatwareRemovals -gt 0) {
    $backupProgressPreference = $progressPreference
    $progressPreference = 'SilentlyContinue' # These Remove-AppxPackage have clunky progress counters, just ignore them
    foreach ($bloatware in $config.settings.bloatwareremoval.bloatware) {
      if ($bloatware.skip -like "True") {
        continue
      }
      $currentBloatwareRemoval++
      Write-Host -ForegroundColor Yellow "Removing Bloatware ($($currentBloatwareRemoval)/$($totalBloatwareRemovals)) '$($bloatware.id)' based on config"
      if ($config.settings.displaydescriptions -like "True" -and $null -ne $bloatware.description) {
        Write-Host "Description: $($bloatware.description)"
      }
      $package = Get-AppxPackage -AllUsers $bloatware.id
      if ($null -ne $package) {
        $package | Remove-AppxPackage
      } else {
        Write-Host -ForegroundColor Green "Bloatware $($bloatware.id) appears to not be installed. Skipping..."
      }
    }
    $progressPreference = $backupProgressPreference
  }
  Write-Host "Section: Remove Bloatware (bloatwareremoval in config), finished"
}
else {
  Write-Host "Section: Remove Bloatware (bloatwareremoval in config), skipping"
}


##########################  Install Chocolatey  ################################
# (Can be run multiple times)
$totalChocoInstalls = $config.settings.chocoinstalls.SelectNodes("./app[(@skip='False')]").count
if ($config.settings.chocoinstalls.skipsection -like "False" -and $totalChocoInstalls -gt 0) {
  Write-Host "Section: Install Chocolatey (chocoinstalls in config), starting..."
  try {
    $chocoVersion = choco -v
  } 
  catch [System.Exception] {
    $chocoFail = "True"
  }
  $chocoVersion = choco -v
  $chocoVersionRegex = '\d{1,}.\d{1,}.\d{1,}' # ex: 2.3.0
  if ((-not($chocoVersion -match $chocoVersionRegex)) -or $chocoFail -like "True"){
    $path = "c:\ProgramData\Chocolatey";
    Write-Host "Cleaning up any previous Chocolatey installs...";
    DeleteDirectory($path);
    Write-Host "Installing Chocolatey...";
    Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'));
    Write-Host -ForegroundColor Red "Chocolatey Installed, restart this script to continue. Exiting."
    Pause
    Exit
  } else {
    Write-Host -ForegroundColor Green "Chocolatey is already installed, version $($chocoVersion ), continuing.";
  }
  Write-Host "Section: Install Chocolatey (chocoinstalls in config), finished"
}
else {
  Write-Host "Section: Install Chocolatey (chocoinstalls in config), skipping"
}

##########################  Install Winget  ################################
# (Can be run multiple times)
$totalWingetInstalls = $config.settings.wingetinstalls.SelectNodes("./app[(@skip='False')]").count
if ($config.settings.wingetinstalls.skipsection -like "False" -and $totalWingetInstalls -gt 0) {
  Write-Host "Section: Install Winget (wingetinstalls in config), starting..."
  try {
    $wingetVersion = winget -v
  }
  catch [System.Exception] {
    $wingetFail = "True"
  }
  $wingetVersionRegex = 'v\d{1,}.\d{1,}.\d{1,}' # ex: v1.9.25180
  if ((-not ($wingetVersion -match $wingetVersionRegex)) -or $wingetFail -like "True" ) {
    Write-Host -ForegroundColor Red "Winget installation not found, you need to solve this problem before this script can progress any further. Exiting."
    Pause
    Exit
  } else {
    Write-Host -ForegroundColor Green "Winget is already installed, version $($wingetVersion), continuing.";
  }
  Write-Host "Section: Install Winget (wingetinstalls in config), finished"
}
else {
  Write-Host "Section: Install Winget (wingetinstalls in config), skipping"
}


##########################  Update Registry Settings  ################################
# (Can be run multiple times)
if ($config.settings.registryedits.skipsection -like "False") {
  Write-Host "Section: Update Registry Settings (registryedits in config), starting..."
  # Run registry edits based on what's in the local config file
  foreach ($regedit in $config.settings.registryedits.regedit) {
    if ($regedit.skip -like "True") {
      continue
    }
    Write-Host -ForegroundColor Yellow "Registry Setting Edit $($regedit.filename) from config"
    if ($config.settings.displaydescriptions -like "True" -and $null -ne $regedit.description) {
      Write-Host "Description: $($regedit.description)"
    }
    $cleanedName = CleanForEnvVar -Dirty $regedit.filename
    $installEnvVarName = "LZB_REGEDITS_$($cleanedName)"
    $installComplete = [Environment]::GetEnvironmentVariable($installEnvVarName, 'User')
    if ($installComplete -like "COMPLETE"){
      Write-Host -ForegroundColor Green "Registry Setting Update '$($regedit.filename)' already completed according to environment variable. Skipping."
      continue
    }
    $regeditfile = ".\LazyBlazeScripts\IncludedRegistrySettings\$($regedit.filename)"
    if (!(test-path -PathType leaf $regeditfile)) {
      Write-Host "ERROR: Registry update file $($regeditfile) not found"
      continue
    }
    Reg import $regeditfile
    if ($LASTEXITCODE -eq 0) {
      Write-Host -ForegroundColor Green "$($regedit.filename) registry update completed successfully."
      [Environment]::SetEnvironmentVariable($installEnvVarName, 'COMPLETE', 'User')
    }
    else {
      Write-Host -ForegroundColor Red "$($regedit.filename) registry update failed"
    }
  }
  Write-Host "Section: Update Registry Settings (registryedits in config), finished"
}
else {
  Write-Host "Section: Update Registry Settings (registryedits in config), skipping"
}


##########################  Update Power Settings  ################################
# (Can be run multiple times)
if ($config.settings.powersettings.skipsection -like "False") {
  Write-Host "Section: Update Power Settings (powersettings in config), starting..."
  $powerSettingsDir = "$($configDir)PowerSettings\"
  $powerSettingsFile = "$($powerSettingsDir)myscheme.pow"
  # Look for an existing power setting backup
  if (test-path -PathType leaf $powerSettingsFile){
    # power settings backup exists, import it
    Write-Host "Power settings backup found at $($powerSettingsFile), importing and setting as active power scheme."
    $newSchemeGuid = New-Guid
    POWERCFG /IMPORT $powerSettingsFile $newSchemeGuid
    POWERCFG /SETACTIVE $newSchemeGuid
    Write-Host -ForegroundColor Green "Power Settings update completed successfully."
  }
  else {
    # Back up the active power scheme to the local config folder
    Write-Host "No power settings backup was found at $($powerSettingsFile), exporting active power scheme for future runs."
    if (!(Test-Path -LiteralPath $powerSettingsDir)) {
    New-Item -ItemType Directory -Path $powerSettingsDir
    }
    $currentSchemeGuid = [regex]::Match((POWERCFG /GETACTIVESCHEME), 'GUID: ([\w-]+)').Groups[1].Value
    POWERCFG /EXPORT $powerSettingsFile $currentSchemeGuid
    Write-Host -ForegroundColor Green "Existing Power Scheme backed up successfully."
  }
  Write-Host "Section: Update Power Settings (powersettings in config), finished"
}
else {
  Write-Host "Section: Update Power Settings (powersettings in config), skipping"
}


###############  Add Exclusions To Backblaze Cloud Backup Config ###############
# (Can be run multiple times, will just reset the config file and start over)
if ($config.settings.backblazeclean.skipsection -like "False") {
  Write-Host "Section: Add Exclusions To Backblaze Cloud Backup Config (backblazeclean in config), starting..."
  $bbconfigfilepath = "C:\ProgramData\Backblaze\bzdata\bzinfo.xml"
  $backupfile = "C:\ProgramData\Backblaze\bzdata\bzinfo_backup.xml"
  if (Test-Path -LiteralPath $backupfile) {
    Write-Host "Existing bzinfo_backup.xml file found. Overwriting bzinfo.xml with bzinfo_backup.xml to restore original config."
    Remove-Item -LiteralPath $bbconfigfilepath
    Copy-Item $backupfile -Destination $bbconfigfilepath
  }
  if (-not (Test-Path -LiteralPath $backupfile)) {
    Write-Host "Creating backup of bzinfo.xml at $backupfile"
    Copy-Item $bbconfigfilepath -Destination $backupfile
  }
  # Backblaze Exclusions List
  foreach ($dir in $config.settings.backblazeclean.dir) {
    if ($dir.skip -like "True") {
      continue
    }
    Write-Host -ForegroundColor Yellow "Adding to Backblaze Exclusion list, dir: $($dir.directory), userdir: $($dir.userdir)..."
    if ($config.settings.displaydescriptions -like "True" -and $null -ne $dir.description) {
      Write-Host "Description: $($dir.description)"
    }
    $fullDirectory = $dir.directory
    if ($dir.userdir -like "True") {
      $fullDirectory = "$($userdir)$($dir.directory)"
    }
    ExcludeFromBackblaze -Directory $fullDirectory
    if ($globalExit -like "True") {
      Pause
      Exit
    }
  }
  # Git Repos With excludefrombackblaze Set To True
  foreach ($gitrepo in $config.settings.gitrepositories.gitrepo) {
    if ($gitrepo.skip -like "True" -or $gitrepo.excludefrombackblaze -like "False") {
      continue
    }
    $fullDirectory = "$($gitrepo.dest)$($gitrepo.name)"
    Write-Host -ForegroundColor Yellow "Adding to Backblaze Exclusion list, dir: $($fullDirectory), userdir: False..."
    ExcludeFromBackblaze -Directory $fullDirectory
    if ($globalExit -like "True") {
      Pause
      Exit
    }
  }
  Write-Host "Section: Add Exclusions To Backblaze Cloud Backup Config (backblazeclean in config), finished"
}
else {
  Write-Host "Section: Add Exclusions To Backblaze Cloud Backup Config (backblazeclean in config), skipping"
}




##########################  Set Wallpaper  ################################
# (Can be run multiple times)
if ($config.settings.setwallpaper.skipsection -like "False") {
  Write-Host "Section: Set Wallpaper (setwallpaper in config), starting..."
  $wallpaperName = $config.settings.setwallpaper.wallpaper
  Write-Host -ForegroundColor Yellow "Setting wallpaper to $($wallpaperName)"
  $wallpapersDir = "$($workingDirectory)\LazyBlazeScripts\IncludedWallpapers\"
  $MyWallpaper="$($wallpapersDir)$($wallpaperName)"
  If (test-path -PathType leaf $MyWallpaper){
    $code = @' 
using System.Runtime.InteropServices; 
namespace Win32{ 
    
     public class Wallpaper{ 
        [DllImport("user32.dll", CharSet=CharSet.Auto)] 
         static extern int SystemParametersInfo (int uAction , int uParam , string lpvParam , int fuWinIni) ; 
         
         public static void SetWallpaper(string thePath){ 
            SystemParametersInfo(20,0,thePath,3); 
         }
    }
 } 
'@
    add-type $code 
    [Win32.Wallpaper]::SetWallpaper($MyWallpaper)
    Write-Host "Section: Set Wallpaper (setwallpaper in config), finished"
  }
  else {
    Write-Host -ForegroundColor Red "Failed to find wallpaper $($MyWallpaper), no wallpaper set."
  }
}
else {
  Write-Host "Section: Set Wallpaper (setwallpaper in config), skipping"
}


##########################  Run Disc Cleanup  ################################
# (Can be run multiple times)
if ($config.settings.disccleanup.skipsection -like "False") {
  Write-Host "Section: Run Disc Cleanup (disccleanup in config), starting..."
  $diskCleanupEnvVarName = "LZB_DISKCLEANUP"
  $diskCleanupComplete = [Environment]::GetEnvironmentVariable($diskCleanupEnvVarName, 'User')
  if ($diskCleanupComplete -like "COMPLETE" -and $config.settings.disccleanup.firstrunonly -like "True") {
    Write-Host -ForegroundColor Green "Run Disc Cleanup already completed according to environment variable $($diskCleanupEnvVarName) and firstrunonly in config is True. Skipping."
  } else {
    Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches\*' | % {
        New-ItemProperty -Path $_.PSPath -Name StateFlags0001 -Value 2 -PropertyType DWord -Force
    };
    # Note: This had arguments "-WindowStyle Hidden -Wait" which seemed to work on my desktop
    # but caused the script to hang on my laptop, be careful putting anything after this in the
    # script because without -wait the disc cleanup will be running and the script will continue.
    Start-Process -FilePath CleanMgr.exe -ArgumentList '/sagerun:1' -WindowStyle Hidden -Wait
    [Environment]::SetEnvironmentVariable($diskCleanupEnvVarName, 'COMPLETE', 'User')
    Write-Host -ForegroundColor Green "Finished Disk Cleanup."
  }
  Write-Host "Section: Run Disc Cleanup (disccleanup in config), finished"
}
else {
  Write-Host "Section: Run Disc Cleanup (disccleanup in config), skipping"
}


##########################  Chocolatey installs  ################################
# (Can be run multiple times)
# Install Chocolatey items from the local config file
$totalChocoInstalls = $config.settings.chocoinstalls.SelectNodes("./app[(@skip='False')]").count
$currentChocoInstall = 0
if ($config.settings.chocoinstalls.skipsection -like "False" -and $totalChocoInstalls -gt 0){
  Write-Host "Section: Chocolatey installs (chocoinstalls in config), starting..."
  foreach ($app in $config.settings.chocoinstalls.app) {
    if ($app.skip -like "True") {
      continue
    }
    try {
      $chocoVersion = choco -v
    } 
    catch [System.Exception] {
      $chocoFail = "True"
    }
    $chocoVersion = choco -v
    $chocoVersionRegex = '\d{1,}.\d{1,}.\d{1,}' # ex: 2.3.0
    if ((-not($chocoVersion -match $chocoVersionRegex)) -or $chocoFail -like "True"){
      Write-Host -ForegroundColor Red "Chocolatey installation not found, you need to solve this problem before this script can progress any further. Exiting."
      Pause
      Exit
    }
    $currentChocoInstall++
    $cleanedId = CleanForEnvVar -Dirty $app.id
    $installEnvVarName = "LZB_CHOCOINSTALLS_$($cleanedId)"
    $installComplete = [Environment]::GetEnvironmentVariable($installEnvVarName, 'User')
    Write-Host -ForegroundColor Yellow  "Chocolatey install ($($currentChocoInstall)/$($totalChocoInstalls)) '$($app.id)' from config"
    if ($config.settings.displaydescriptions -like "True" -and $null -ne $app.description) {
      Write-Host "Description: $($app.description)"
    }
    if ($installComplete -like "COMPLETE"){
      Write-Host -ForegroundColor Green "Choco install '$($app.id)' already completed according to environment variable. Skipping."
      continue
    }
    choco install $app.id -y
    if ($LASTEXITCODE -eq 0) {
      Write-Host -ForegroundColor Green "$($app.id) successfully installed."
      [Environment]::SetEnvironmentVariable($installEnvVarName, 'COMPLETE', 'User')
    }
    else {
      Write-Host -ForegroundColor Red "$($app.id) installation failed"
    }
  }
  Write-Host "Section: Chocolatey installs (chocoinstalls in config), finished"
}
else {
  Write-Host "Section: Chocolatey installs (chocoinstalls in config), skipping"
}


##########################  winget installs  ################################
# (Can be run multiple times)
# Install winget items from the local config file
$totalWingetInstalls = $config.settings.wingetinstalls.SelectNodes("./app[(@skip='False')]").count
$currentWingetInstall = 0
if ($totalWingetInstalls -gt 0 -or  $config.settings.visualstudio.app.skip -like "False"){
  Write-Host "Section: winget installs (wingetinstalls in config), starting..."
  foreach ($app in $config.settings.wingetinstalls.app) {
    if ($app.skip -like "True") {
      continue
    }
    try {
      $wingetVersion = winget -v
    }
    catch [System.Exception] {
      $wingetFail = "True"
    }
    $wingetVersionRegex = 'v\d{1,}.\d{1,}.\d{1,}' # ex: v1.9.25180
    if ((-not ($wingetVersion -match $wingetVersionRegex)) -or $wingetFail -like "True" ) {
      Write-Host -ForegroundColor Red "Winget installation not found, you need to solve this problem before this script can progress any further. Exiting."
      Pause
      Exit
    }
    $currentWingetInstall++
    $cleanedId = CleanForEnvVar -Dirty $app.id
    $installEnvVarName = "LZB_WINGETINSTALLS_$($cleanedId)"
    $installComplete = [Environment]::GetEnvironmentVariable($installEnvVarName, 'User')
    Write-Host -ForegroundColor Yellow "Winget install ($($currentWingetInstall)/$($totalWingetInstalls)) '$($app.id)' from config..."
    if ($config.settings.displaydescriptions -like "True" -and $null -ne $app.description) {
      Write-Host "Description: $($app.description)"
    }
    if ($installComplete -like "COMPLETE"){
      Write-Host -ForegroundColor Green "Winget install '$($app.id)' already completed according to environment variable. Skipping."
      continue
    }
    if ($null -ne $app.msstore -and $app.msstore -like "True") {
      winget install --id $app.id --exact --accept-source-agreements --accept-package-agreements --source=msstore
    }
    elseif ($null -ne $app.override) {
      winget install --id $app.id --exact --accept-source-agreements --accept-package-agreements --override $app.override
    }
    else {
      winget install --id $app.id --exact --accept-source-agreements --accept-package-agreements
    }
    if ($LASTEXITCODE -eq 0) {
      Write-Host -ForegroundColor Green "$($app.id) successfully installed."
      [Environment]::SetEnvironmentVariable($installEnvVarName, 'COMPLETE', 'User')
    }
    else {
      Write-Host -ForegroundColor Red "$($app.id) installation failed"
    }
  }
  Write-Host "Section: winget installs (wingetinstalls in config), finished"
}
else {
  Write-Host "Section: winget installs (wingetinstalls in config), skipping"
}


##########################  Install Visual Studio Community  ################################
# (Can be run multiple times)
if ($config.settings.visualstudio.skipsection -like "False") {
  Write-Host "Section: Install Visual Studio Community (visualstudio in config), starting..."
  try {
    $wingetVersion = winget -v
  }
  catch [System.Exception] {
    $wingetFail = "True"
  }
  $wingetVersionRegex = 'v\d{1,}.\d{1,}.\d{1,}' # ex: v1.9.25180
  if ((-not ($wingetVersion -match $wingetVersionRegex)) -or $wingetFail -like "True" ) {
    Write-Host -ForegroundColor Red "Winget installation not found, you need to solve this problem before this script can progress any further. Exiting."
    Pause
    Exit
  }
  $cleanedId = CleanForEnvVar -Dirty $config.settings.visualstudio.app.id
  $installEnvVarName = "LZB_WINGETINSTALLS_$($cleanedId)"
  $installComplete = [Environment]::GetEnvironmentVariable($installEnvVarName, 'User')
  Write-Host -ForegroundColor Yellow "Winget install '$($config.settings.visualstudio.app.id)' from config..."
  if ($config.settings.displaydescriptions -like "True" -and $null -ne $config.settings.visualstudio.app.description) {
    Write-Host "Description: $($config.settings.visualstudio.app.description)"
  }
  if ($installComplete -like "COMPLETE"){
    Write-Host -ForegroundColor Green "Winget install '$($config.settings.visualstudio.app.id)' already completed according to environment variable. Skipping."
  }
  else {
    if ($config.settings.visualstudio.options.installfromsnapshot -like "True") {
      # Install Visual Studio Community with options from existing my.vsconfig snapshot file
      $visualStudioInstallConfigFile = "$($configDir)VisualStudio\my.vsconfig"
      if (test-path -PathType leaf $visualStudioInstallConfigFile) {
        winget install --id Microsoft.VisualStudio.2022.Community --exact --accept-source-agreements --accept-package-agreements --override "--passive --wait --config $($visualStudioInstallConfigFile)"
      }
      else {
        Write-Host -ForegroundColor Red "Failed to find my.vsconfig file in $($configDir)VisualStudio\, if you want to install Visual Studio Community either provide a my.vsconfig file or set installfromsnapshot to False in your LocalConfig.xml"
      }
    }
    else {
      # Install Visual Studio Community using custom arguments
      $workloads = ""
      foreach ($workload in $config.settings.visualstudio.workloads.workload) {
        if ($workload.skip -like "False") {
          $workloads += " --add $($workload.id)"
        }
      }
      winget install --id $($config.settings.visualstudio.app.id) --exact --accept-source-agreements --accept-package-agreements --silent --disable-interactivity --override "--passive --wait$($workloads)"
      if ($LASTEXITCODE -eq 0) {
        Write-Host -ForegroundColor Green "$($config.settings.visualstudio.app.id) successfully installed."
        [Environment]::SetEnvironmentVariable($installEnvVarName, 'COMPLETE', 'User')
      }
      else {
        Write-Host -ForegroundColor Red "$($config.settings.visualstudio.app.id) installation failed"
        Write-Host -ForegroundColor Red "The installation log file is at '$($userdir)AppData\Local\Temp\' and the log file name looks like dd_setup_* or dd_installer_* or dd_backgrounddownload_*"
        Write-Host -ForegroundColor Red "You may need to uninstall the Visual Studio Installer, this process seems to struggle when you're in a state with the Visual Studio Installer installed but Visual Studio Community not installed."
      }
    }
  }
  Write-Host "Section: Install Visual Studio Community (visualstudio in config), finished"
}
else {
  Write-Host "Section: Install Visual Studio Community (visualstudio in config), skipping"
}


##########################  Set Chrome As Default Browser  ################################
# (Lets only run this one once)
# Changing default browser for Windows 11 only #
if ($config.settings.setchromedefaultbrowser.skipsection -like "False") {
  Write-Host "Section: Set Chrome As Default Browser (setchromedefaultbrowser in config), starting..."
  Write-Host -ForegroundColor Yellow "Set Chrome As Default Browser..."
  $chrDftEnvVarName = "LZB_SETCHROMEASDEFAULT"
  $stepComplete = [Environment]::GetEnvironmentVariable($chrDftEnvVarName, 'User')
  if ($stepComplete -like "COMPLETE"){
    Write-Host -ForegroundColor Green "Set Chrome as Default Browser already completed according to environment variable $($chrDftEnvVarName). Skipping."
  }
  else {
    if ($env:OS -ne 'Windows_NT') { throw 'This script runs on Windows only' }
    Stop-Process -ErrorAction Ignore -Name SystemSettings
    Start-Process ms-settings:defaultapps
    $ps = Get-Process -ErrorAction Stop SystemSettings
    do {
      Start-Sleep -Milliseconds 100
      $ps.Refresh()
    } while ([int] $ps.MainWindowHandle)
    Start-Sleep -Milliseconds 200
    # Entering key strokes mode.
    $shell = New-Object -ComObject WScript.Shell
    # Tab to the "Set defaults for applications".
    foreach ($i in 1..4) { $shell.SendKeys('{TAB}'); Start-Sleep -milliseconds 100 }
    # Set Chrom as a defaults browser
    $shell.SendKeys("chrom"); Start-Sleep -seconds 1
    $shell.SendKeys('{TAB}'); Start-Sleep -milliseconds 100
    $shell.SendKeys('{ENTER}'); Start-Sleep -milliseconds 100
    $shell.SendKeys('{ENTER}'); Start-Sleep -milliseconds 100
    $shell.SendKeys('%{F4}')
    [Environment]::SetEnvironmentVariable($chrDftEnvVarName, 'COMPLETE', 'User')
    Write-Host -ForegroundColor Green "Finished Set Chrome As Default Browser."
  }
  Write-Host "Section: Set Chrome As Default Browser (setchromedefaultbrowser in config), finished"
}
else {
  Write-Host "Section: Set Chrome As Default Browser (setchromedefaultbrowser in config), skipping"
}


##########################  Populate Config Files  ################################
# (Lets only run this one once)
if ($config.settings.appdatabackups.skipsection -like "False") {
  Write-Host "Section: Populate Config Files (appdatabackups in config), starting..."
  Write-Host -ForegroundColor Yellow "Populate Config Files..."
  $popConfigsEnvVarName = "LZB_POPULATECONFIGS"
  $stepComplete = [Environment]::GetEnvironmentVariable($popConfigsEnvVarName, 'User')
  if ($stepComplete -like "COMPLETE"){
    Write-Host -ForegroundColor Green "Populate Various Config Files already completed according to environment variable $($popConfigsEnvVarName). Skipping."
  }
  else {
    foreach ($backup in $config.settings.appdatabackups.backup) {
      if ($backup.skip -like "True") {
        continue
      }
      Write-Host "Inserting $($backup.filename) from config"
      if ($config.settings.displaydescriptions -like "True" -and $null -ne $backup.description) {
        Write-Host $backup.description
      }
      PopulateConfigFile -FileName $backup.filename -SourceDir "$($configDir)$($backup.configfolder)\" -TargetDir "$($userdir)$($backup.appdatadir)"
    }
    [Environment]::SetEnvironmentVariable($popConfigsEnvVarName, 'COMPLETE', 'User')
    Write-Host -ForegroundColor Green "Finished Populate Config Files."
  }
  Write-Host "Section: Populate Config Files (appdatabackups in config), finished"
}
else {
  Write-Host "Section: Populate Config Files (appdatabackups in config), skipping"
}



##########################  Clean Desktop  ################################
# (Can be run multiple times)
if ($config.settings.cleandesktop.skipsection -like "False") {
  Write-Host "Section: Clean Desktop (cleandesktop in config), starting..."
  Write-Host -ForegroundColor Yellow "Clean Desktop..."
  $shortcutsFolderName = "Shortcuts"
  $desktopPath = "$($userdir)Desktop\"
  if ($config.settings.cleandesktop.options.onedrive -like "True"){
    $desktopPath = "$($userdir)OneDrive\Desktop\"
  }
  $publicDesktopPath = "C:\Users\Public\Desktop\"
  $shortcutsDestination = "$($userdir)$($shortcutsFolderName)\"
  $shortcutsShortcut = "$($desktopPath)$($shortcutsFolderName).lnk"
  Write-Host "Moving Shortcuts on Desktop into $($shortcutsDestination)"
  If (test-path -PathType leaf $shortcutsShortcut){
    Write-Host "Deleting $($shortcutsShortcut)"
    Remove-Item -LiteralPath $shortcutsShortcut
  }
  MoveShortcuts -SourceDir $desktopPath -TargetDir $shortcutsDestination
  MoveShortcuts -SourceDir $publicDesktopPath -TargetDir $shortcutsDestination
  $WshShell = New-Object -COMObject WScript.Shell
  $Shortcut = $WshShell.CreateShortcut($shortcutsShortcut)
  $Shortcut.TargetPath = $shortcutsDestination
  $Shortcut.Save()
  Write-Host -ForegroundColor Green "Finished Clean Desktop."
  Write-Host "Section: Clean Desktop (cleandesktop in config), finished"
}
else {
  Write-Host "Section: Clean Desktop (cleandesktop in config), skipping"
}


##########################  Remove Broken Shortcuts  ################################
# (Can be run multiple times)
if ($config.settings.brokenshortcutremoval.skipsection -like "False") {
  Write-Host "Section: Remove Broken Shortcuts (brokenshortcutremoval in config), starting..."
  Write-Host -ForegroundColor Yellow "Remove Broken Shortcuts..."
  foreach ($dir in $config.settings.brokenshortcutremoval.dir) {
    if ($dir.skip -like "True") {
      continue
    }
    $fullDirectory = $dir.directory
    if ($dir.userdir -like "True") {
      $fullDirectory = "$($userdir)$($dir.directory)"
    }
    Write-Host "Cleaning broken shortcuts in $($fullDirectory)"
    if ($config.settings.displaydescriptions -like "True" -and $null -ne $dir.description) {
      Write-Host $dir.description
    }
    RemoveBrokenShortcuts -Directory $fullDirectory
  }
  Write-Host -ForegroundColor Green "Finished Remove Broken Shortcuts."
  Write-Host "Section: Remove Broken Shortcuts (brokenshortcutremoval in config), finished"
}
else {
  Write-Host "Section: Remove Broken Shortcuts (brokenshortcutremoval in config), skipping"
}


##########################  Clean System Using DISM and SFC  ################################
# (Can be run multiple times)
# This section was added in an attempt to fix the black background bug I've been having. It doesn't seem to have helped.
# Deployment Image Servicing and Management tool
if ($config.settings.rundismclean.skipsection -like "False") {
  Write-Host "Section: Clean System Using DISM and SFC (rundismclean in config), starting..."
  Write-Host -ForegroundColor Yellow "Clean System Using DISM and SFC..."
  $dismCleanEnvVarName = "LZB_DISMCLEAN"
  $dismCleanComplete = [Environment]::GetEnvironmentVariable($dismCleanEnvVarName, 'User')
  if ($dismCleanComplete -like "COMPLETE" -and $config.settings.rundismclean.firstrunonly -like "True") {
    Write-Host -ForegroundColor Green "Clean System Using DISM and SFC already completed according to environment variable $($dismCleanEnvVarName) and firstrunonly in config is True. Skipping."
  } else {
    Write-Host "Cleaning System with DISM"
    DISM /Online /Cleanup-image /Restorehealth
    #System File Checker tool
    Write-Host "Cleaning System with SFC"
    sfc /scannow
    [Environment]::SetEnvironmentVariable($dismCleanEnvVarName, 'COMPLETE', 'User')
    Write-Host -ForegroundColor Green "Finished Clean System Using DISM and SFC."
  }
  Write-Host "Section: Clean System Using DISM and SFC (rundismclean in config), finished"
}
else {
  Write-Host "Section: Clean System Using DISM and SFC (rundismclean in config), skipping"
}


##########################  Schedule Auto Backup of Settings  ################################
# (Lets only run this one once)
if ($config.settings.scheduledbackuptask.skipsection -like "False") {
  Write-Host "Section: Schedule Auto Backup of Settings (scheduledbackuptask in config), starting..."
  Write-Host -ForegroundColor Yellow "Schedule Auto Backup of Settings..."
  $scheduledTaskName = "BackupSettingsLazyBlaze"
  if ($config.settings.scheduledbackuptask.options.overwrite -like "True") {
    Write-Host "Option overwrite is True, checking for exising scheduled task..."
    # Find existing scheduled task
    if (Get-ScheduledTask -TaskName $scheduledTaskName -ErrorAction SilentlyContinue){
      Write-Host "Found existing scheduled task $($scheduledTaskName), deleting..."
      # Delete existing scheduled task
      Unregister-ScheduledTask -TaskName $scheduledTaskName -Confirm:$false
    }
    else{
      Write-Host "Did not find existing scheduled task $($scheduledTaskName)"
    }
  }
  if ((-not ($config.settings.scheduledbackuptask.options.overwrite -like "True")) -and (Get-ScheduledTask -TaskName $scheduledTaskName -ErrorAction SilentlyContinue)){
    Write-Host "Option overwrite is not True and scheduled task $($scheduledTaskName) already exists, skipping"
  }
  else {
    Write-Host "Starting creating scheduled task $($scheduledTaskName)..."
    $installDir = "$($workingDirectory)\"
    Write-Host "configDir: $($installDir)"
    $scriptedBackupName = "Backup.ps1"
    $localScriptedBackupFile = "$($installDir)LazyBlazeScripts\$($scriptedBackupName)"
    $user = "NT AUTHORITY\SYSTEM"
    $trigger = New-ScheduledTaskTrigger -Daily -At '12:15 PM' 
    $action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-WindowStyle Hidden -File `"$localScriptedBackupFile`"" -WorkingDirectory $installDir
    Register-ScheduledTask -Action $action -Trigger $trigger -User $user -TaskName $scheduledTaskName -Description "run lazyblaze backups daily"
    Write-Host -ForegroundColor Green "Finished creating scheduled task $($scheduledTaskName)."
  }
  Write-Host "Section: Schedule Auto Backup of Settings (scheduledbackuptask in config), finished"
}
else {
  Write-Host "Section: Schedule Auto Backup of Settings (scheduledbackuptask in config), skipping"
}

##########################  Clean Old Schedule Auto Backup of Settings  ################################
# Check for leftovers from old script versions and clean them up.
if ($config.settings.scheduledbackuptask.cleanold -like "True") {
  Write-Host "Section: Clean Old Schedule Auto Backup of Settings (scheduledbackuptask in config), starting..."
  $oldSchBkupEnvVarName = "LZB_SCHEDULEBACKUP"
  if ([Environment]::GetEnvironmentVariable($oldSchBkupEnvVarName, 'User')){
    Write-Host -ForegroundColor Yellow "Old environment variable $($oldSchBkupEnvVarName) found, deleting..."
    [Environment]::SetEnvironmentVariable($oldSchBkupEnvVarName, $null, 'User')
  }
  $oldScheduledTaskName = "BackupSettings"
  if (Get-ScheduledTask -TaskName $oldScheduledTaskName -ErrorAction SilentlyContinue){
    Write-Host "Old scheduled task $($oldScheduledTaskName) found, deleting..."
    Unregister-ScheduledTask -TaskName $oldScheduledTaskName -Confirm:$false
  }
  Write-Host "Section: Clean Old Schedule Auto Backup of Settings (scheduledbackuptask in config), finished"
}


##########################  Stop Logging  ################################
if ($logStarted -like "True") {
  Stop-Transcript
}


##########################  Success Message  ################################
Write-Host -ForegroundColor Green "Execution of script $($globalPrimaryScriptName) successfully finished."
Pause