param (
  $workingDirectory
)
  
$PrimaryScriptName = "InstallApps"
$requireAdmin = "True"
  
  
##########################  Fix Working Directory  ################################
# If launching as admin from a .bat file it will default the working directory to system32
# so we need to pass what the working directory should be as a parameter
$currentWorkingDirectory = (Get-Item .).FullName
if ($null -ne $workingDirectory -and (-not($workingDirectory -like $currentWorkingDirectory))) {
  Write-Host -ForegroundColor Yellow "Setting working directory to '$workingDirectory'"
  Set-Location $workingDirectory
}
  
  
##########################  Run SharedFunctionsAndChecks.ps1  ################################
# Execute script in the current session context, variables are shared between the scripts
. ".\SharedFunctionsAndChecks.ps1"
if ($globalExit -like "True") {
  Pause
  Exit
}
if (-not($ranSharedFunctionsAndChecks -like "True")) {
  Write-Host -ForegroundColor Red "SharedFunctionsAndChecks.ps1 script did not finish successfully, exiting."
  Pause
  Exit
}


##########################  Remove Bloatware  ################################
# (Can be run multiple times)
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


##########################  Install Chocolatey  ################################
# (Can be run multiple times)
$totalChocoInstalls = $config.settings.chocoinstalls.SelectNodes("./app[(@skip='False')]").count
if ($totalChocoInstalls -gt 0) {
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
}

##########################  Install Winget  ################################
# (Can be run multiple times)
$totalWingetInstalls = $config.settings.wingetinstalls.SelectNodes("./app[(@skip='False')]").count
if ($totalWingetInstalls -gt 0) {
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
}

##########################  Update Registry Settings  ################################
# (Can be run multiple times)
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
  $installEnvVarName = "NMSS_REGEDITS_$($cleanedName)"
  $installComplete = [Environment]::GetEnvironmentVariable($installEnvVarName, 'User')
  if ($installComplete -like "COMPLETE"){
    Write-Host -ForegroundColor Green "Registry Setting Update '$($regedit.filename)' already completed according to environment variable. Skipping."
    continue
  }
  $regeditfile = "registrysettings\$($regedit.filename)"
  if (!(test-path -PathType leaf $regeditfile)) {
    Write-Host "ERROR: Registry update file $($regeditfile) not found"
    continue
  }
  Reg import "registrysettings\$($regedit.filename)"
  if ($LASTEXITCODE -eq 0) {
    Write-Host -ForegroundColor Green "$($regedit.filename) registry update completed successfully."
    [Environment]::SetEnvironmentVariable($installEnvVarName, 'COMPLETE', 'User')
  }
  else {
    Write-Host -ForegroundColor Red "$($regedit.filename) registry update failed"
  }
}


##########################  Update Power Settings  ################################
# (Can be run multiple times)
if ($config.settings.modifypowersettings -like "True") {
  Write-Host -ForegroundColor Yellow "Updating Power settings..."
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
}


###############  Add Exclusions To Backblaze Cloud Backup Config ###############
# (Can be run multiple times, will just reset the config file and start over)
if ($config.settings.usingbackblaze -like "True") {
  Write-Host -ForegroundColor Yellow "Configuring Backblaze Exclusion List..."
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
  Write-Host -ForegroundColor Green "Finished Configuring Backblaze Exclusion List Successfully."
}




##########################  Set Wallpaper  ################################
# (Can be run multiple times)
Write-Host -ForegroundColor Yellow "Setting wallpaper to $($wallpaperName)"
$wallpapersDir = "$($configDir)wallpapers\"
$MyWallpaper="$($wallpapersDir)$($wallpaperName)"
if (!(Test-Path -LiteralPath $wallpapersDir)){
  New-Item -ItemType Directory -Path $wallpapersDir 
}
If (!(test-path -PathType leaf $MyWallpaper)){
  Copy-Item -Path ".\wallpapers\$($wallpaperName)" -Destination $MyWallpaper
}
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
Write-Host -ForegroundColor Green "Finished Setting Wallpaper."


##########################  Run Disc Cleanup  ################################
# (Can be run multiple times)
Write-Host -ForegroundColor Yellow "Running Disk Cleanup..."
$diskCleanupEnvVarName = "NMSS_DISKCLEANUP"
$diskCleanupComplete = [Environment]::GetEnvironmentVariable($diskCleanupEnvVarName, 'User')
if ($diskCleanupComplete -like "COMPLETE" -and (-not($config.settings.rundisccleanupmorethanonce -like "True"))) {
  Write-Host -ForegroundColor Green "Run Disc Cleanup already completed according to environment variable $($diskCleanupEnvVarName) and rundisccleanupmorethanonce in config is False. Skipping."
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


##########################  Chocolatey installs  ################################
# (Can be run multiple times)
# Install Chocolatey items from the local config file
$totalChocoInstalls = $config.settings.chocoinstalls.SelectNodes("./app[(@skip='False')]").count
if ($totalChocoInstalls -gt 0){
  Write-Host -ForegroundColor Yellow "Starting Chocolatey Installs..."
}
$currentChocoInstall = 0
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
  $installEnvVarName = "NMSS_CHOCOINSTALLS_$($cleanedId)"
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
if ($totalChocoInstalls -gt 0){
  Write-Host -ForegroundColor Green "Finished Chocolatey Installs."
}


##########################  winget installs  ################################
# (Can be run multiple times)
# Install winget items from the local config file
$totalWingetInstalls = $config.settings.wingetinstalls.SelectNodes("./app[(@skip='False')]").count
if ($totalWingetInstalls -gt 0 -or  $config.settings.visualstudio.app.skip -like "False"){
  Write-Host -ForegroundColor Yellow "Starting Winget Installs..."
}
$currentWingetInstall = 0
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
  $installEnvVarName = "NMSS_WINGETINSTALLS_$($cleanedId)"
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


##########################  Install Visual Studio Community  ################################
# (Can be run multiple times)
# Install Visual Studio Community using custom arguments
if ($config.settings.visualstudio.app.skip -like "False") {
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
  $installEnvVarName = "NMSS_WINGETINSTALLS_$($cleanedId)"
  $installComplete = [Environment]::GetEnvironmentVariable($installEnvVarName, 'User')
  Write-Host -ForegroundColor Yellow "Winget install '$($config.settings.visualstudio.app.id)' from config..."
  if ($config.settings.displaydescriptions -like "True" -and $null -ne $config.settings.visualstudio.app.description) {
    Write-Host "Description: $($config.settings.visualstudio.app.description)"
  }
  if ($installComplete -like "COMPLETE"){
    Write-Host -ForegroundColor Green "Winget install '$($config.settings.visualstudio.app.id)' already completed according to environment variable. Skipping."
  }
  else {
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
if ($totalWingetInstalls -gt 0 -or  $config.settings.visualstudio.app.skip -like "False"){
  Write-Host -ForegroundColor Green "Finished Winget Installs."
}


##########################  Set Chrome As Default Browser  ################################
# (Lets only run this one once)
# Changing default browser for Windows 11 only #
Write-Host -ForegroundColor Yellow "Set Chrome As Default Browser..."
$chrDftEnvVarName = "NMSS_SETCHROMEASDEFAULT"
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


##########################  Populate Config Files  ################################
# (Lets only run this one once)
Write-Host -ForegroundColor Yellow "Populate Config Files..."
$popConfigsEnvVarName = "NMSS_POPULATECONFIGS"
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



##########################  Clean Desktop  ################################
# (Can be run multiple times)
Write-Host -ForegroundColor Yellow "Clean Desktop..."
$shortcutsFolderName = "Shortcuts"
$desktopPath = "$($userdir)Desktop\"
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


##########################  Remove Broken Shortcuts  ################################
# (Can be run multiple times)
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


##########################  Clean System Using DISM and SFC  ################################
# (Can be run multiple times)
# This section was added in an attempt to fix the black background bug I've been having. It doesn't seem to have helped.
# Deployment Image Servicing and Management tool
Write-Host -ForegroundColor Yellow "Clean System Using DISM and SFC..."
$dismCleanEnvVarName = "NMSS_DISMCLEAN"
$dismCleanComplete = [Environment]::GetEnvironmentVariable($dismCleanEnvVarName, 'User')
if ($dismCleanComplete -like "COMPLETE" -and (-not($config.settings.rundismcleanmorethanonce -like "True"))) {
  Write-Host -ForegroundColor Green "Clean System Using DISM and SFC already completed according to environment variable $($dismCleanEnvVarName) and rundismcleanmorethanonce in config is False. Skipping."
} else {
  Write-Host "Cleaning System with DISM"
  DISM /Online /Cleanup-image /Restorehealth
  #System File Checker tool
  Write-Host "Cleaning System with SFC"
  sfc /scannow
  [Environment]::SetEnvironmentVariable($dismCleanEnvVarName, 'COMPLETE', 'User')
  Write-Host -ForegroundColor Green "Finished Clean System Using DISM and SFC."
}


##########################  Schedule Auto Backup of Settings  ################################
# (Lets only run this one once)
Write-Host -ForegroundColor Yellow "Schedule Auto Backup of Settings..."
$schBkupEnvVarName = "NMSS_SCHEDULEBACKUP"
$stepComplete = [Environment]::GetEnvironmentVariable($schBkupEnvVarName, 'User')
if ($stepComplete -like "COMPLETE"){
  Write-Host -ForegroundColor Green "Schedule Auto Backup of Settings already completed according to environment variable $($schBkupEnvVarName). Skipping."
}
else {
  $scriptedBackupName = "Backup.ps1"
  $localScriptedBackupFile = "$($configDir)$($scriptedBackupName)"
  $user = "NT AUTHORITY\SYSTEM"
  $trigger = New-ScheduledTaskTrigger -Daily -At '12:15 PM' 
  $action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-WindowStyle Hidden -File `"$localScriptedBackupFile`"" -WorkingDirectory $configDir
  Register-ScheduledTask -Action $action -Trigger $trigger -User $user -TaskName "BackupSettings" -Description "run lazyblaze backups daily"
  [Environment]::SetEnvironmentVariable($schBkupEnvVarName, 'COMPLETE', 'User')
  Write-Host -ForegroundColor Green "Finished Schedule Auto Backup of Settings."
}


##########################  Stop Logging  ################################
if ($logStarted -like "True") {
  Stop-Transcript
}


##########################  Success Message  ################################
Write-Host -ForegroundColor Green "Execution of script $($PrimaryScriptName) successfully finished."
Pause