param (
  $workingDirectory
)

$globalPrimaryScriptName = "Install"
$globalRequireAdmin = "True"


##########################  Start Logging  ################################
$date = (Get-Date).ToString("yyyy-MM-dd_HHmmss")
$logFile = ".\Logs\$($date)_$($globalPrimaryScriptName)_log.txt"
Start-Transcript -Path $logFile
$logStarted = "True"


##########################  Fix Working Directory  ################################
# If launching as admin from a .bat file it will default the working directory to system32
# so we need to pass what the working directory should be as a parameter
$currentWorkingDirectory = (Get-Item .).FullName
if ($null -ne $workingDirectory -and (-not($workingDirectory -like $currentWorkingDirectory))) {
  Write-Host -ForegroundColor Yellow "Setting working directory to '$workingDirectory'"
  Set-Location $workingDirectory
}


Import-Module ".\FilesToInstall\PowershellModules\IsAdmin.psm1"
Import-Module ".\FilesToInstall\PowershellModules\ReplaceLine.psm1"


if (-not (IsAdmin)) {
  Write-Host -ForegroundColor Red "Script must be run as administrator, exiting."
  Pause
  Exit
}


##########################  Install Steps  ################################
# Determine install version (from InstallConfig.xml)
# Determine install location (from InstallConfig.xml)
#   Also check environment variable?
# Determine installed version
#   Does it exist?
#   Is it the same? minor change? major change?
# Tell user where LazyBlaze will be installed
#   Prompt something like "press y to continue"
# Warn user if continuing will result in a breaking change
#   Prompt something like "press y to continue"
# Copy sample config into install directory if it doesn't exist
# Copy scripts from repo to install location
#   Insert version info at the top of the scripts


##########################  Get Install Config  ################################
$configLocationXmlFileName = ".\Installer\InstallConfig.xml"
if (-not (test-path -PathType leaf $configLocationXmlFileName)) {
  Write-Host -ForegroundColor Red "Failed to find config $($configLocationXmlFileName), exiting."
  Pause
  Exit
}
$installConfig = [xml](Get-Content $configLocationXmlFileName)


##########################  Determine Install Location  ################################
$installOverrideEnvVarName = "LZB_INSTALL_OVERRIDE"
$configDirectoryOverride = $installConfig.settings.installdirectory.directoryoverride
$envDirectoryOverride = [Environment]::GetEnvironmentVariable($installOverrideEnvVarName, 'User')
if (-not ($null -eq $configDirectoryOverride -or $configDirectoryOverride -like "")) {
  # Use directoryoverride setting from InstallConfig.xml for install location
  Write-Host "The directoryoverride setting in InstallConfig.xml has been set and will be used for install location."
  Write-Host "This will install LazyBlaze to the override location, and also save the location to the $($installOverrideEnvVarName) environment variable for future use."
  Write-Host -ForegroundColor Yellow "LazyBlaze installation location is set to '$($configDirectoryOverride)'"
  $userInput = Read-Host "Enter 'y' to continue installation"
  if (-not ($userInput -ieq 'y')) {
    Write-Host -ForegroundColor Red "Input did not match 'y', exiting."
    Pause
    Exit
  }
  Write-Host -ForegroundColor Yellow "Setting user environment variable $($installOverrideEnvVarName) = $($configDirectoryOverride)"
  [Environment]::SetEnvironmentVariable($installOverrideEnvVarName, $configDirectoryOverride, 'User')
  $installLocation = $configDirectoryOverride
}
elseif (-not ($null -eq $envDirectoryOverride -or $envDirectoryOverride -like "")) {
  # Use saved environment variable for install location
  Write-Host -ForegroundColor Yellow "The user environment variable $($installOverrideEnvVarName) was found to have a value and will be used for install location."
  Write-Host -ForegroundColor Yellow "LazyBlaze installation location is set to '$($envDirectoryOverride)'"
  $userInput = Read-Host "Enter 'y' to continue installation"
  if (-not ($userInput -ieq 'y')) {
    Write-Host -ForegroundColor Red "Input did not match 'y', exiting."
    Pause
    Exit
  }
  $installLocation = $envDirectoryOverride
}
else {
  # Use default combination of user name and machine name for install location in OneDrive
  $sysMachineName = Invoke-Expression -Command 'hostname'
  Write-Host "Building default install location using user directory $($env:USERPROFILE) and machine name $($sysMachineName)."
  $defaultInstallLocation = "$($env:USERPROFILE)\OneDrive\LazyBlaze_$($sysMachineName)\"
  Write-Host -ForegroundColor Yellow "LazyBlaze installation location is set to '$($defaultInstallLocation)'"
  Write-Host "If you would like to change the installation location you can choose to not continue this installation, set the directoryoverride value in InstallConfig.xml, and re-run this installer."
  $userInput = Read-Host "Enter 'y' to continue installation"
  if (-not ($userInput -ieq 'y')) {
    Write-Host -ForegroundColor Red "Input did not match 'y', exiting."
    Pause
    Exit
  }
  $installLocation = $defaultInstallLocation
}


##########################  Validate Install Version  ################################
$installMajorVersion = $installConfig.settings.version.major
$installMinorVersion = $installConfig.settings.version.minor
function IsNumeric ($Value) {
  return $Value -match "^[\d\.]+$"
}
if (-not (IsNumeric $installMajorVersion)) {
  Write-Host -ForegroundColor Red "Major version in install config not valid '$($installMajorVersion)', exiting."
  Pause
  Exit
}
if (-not (IsNumeric $installMinorVersion)) {
  Write-Host -ForegroundColor Red "Minor version in install config not valid '$($installMinorVersion)', exiting."
  Pause
  Exit
}


##########################  Check For Existing Install  ################################
if (Test-Path -LiteralPath $installLocation) {
  Write-Host -ForegroundColor Yellow "An existing lazyblaze install was found."
  Write-Host "Continuing with this installation will overwrite existing scripts, but user specific configuration will not be affected." 
  $userInput = Read-Host "Enter 'y' to update your LazyBlaze"
  if (-not ($userInput -ieq 'y')) {
    Write-Host -ForegroundColor Red "Input did not match 'y', exiting."
    Pause
    Exit
  }
}


##########################  Add User Config  ################################
$userConfigFileName = "$($installLocation)Config.xml"
$configVersionRegex = '\s*<version major=.* minor=.*></version>'
$newVersionLineForConfig = "  <version major=""$($installMajorVersion)"" minor=""$($installMinorVersion)""></version>"
if (-not (test-path -PathType leaf $userConfigFileName)) {
  Write-Host "Existing config not found, creating '$($userConfigFileName)'"
  if (!(Test-Path -LiteralPath $installLocation)) {
    New-Item -ItemType Directory -Path $installLocation 
  }
  Copy-Item -Path ".\FilesToInstall\Config.xml" -Destination $userConfigFileName
  ReplaceLine -LineRegex $configVersionRegex -NewLine $newVersionLineForConfig -File $userConfigFileName
}


##########################  Check User Config Version  ################################
$userConfig = [xml](Get-Content $userConfigFileName)
$userConfigMajorVersion = $userConfig.settings.version.major
$userConfigMinorVersion = $userConfig.settings.version.minor
if (-not (IsNumeric $userConfigMajorVersion)) {
  Write-Host -ForegroundColor Red "Major version '$($userConfigMajorVersion)' in user config $($userConfigFileName) not valid, exiting."
  Pause
  Exit
}
if (-not (IsNumeric $userConfigMinorVersion)) {
  Write-Host -ForegroundColor Red "Minor version '$($userConfigMinorVersion)' in user config $($userConfigFileName) not valid, exiting."
  Pause
  Exit
}
if (($userConfigMajorVersion -gt $installMajorVersion) -or (($userConfigMajorVersion -eq $installMajorVersion) -and ($userConfigMinorVersion -gt $installMinorVersion))) {
  # User has somehow ended up with a user config version that's more recent than the installer that's running.
  Write-Host -ForegroundColor Red "You've somehow got a version of your user config that's more recent than the installer. I'm going to be honest, I'm confused. I give up."
  Pause
  Exit
}
if ($userConfigMajorVersion -lt $installMajorVersion) {
  # User has a config that is old enough that the install has breaking changes
  Write-Host "The installer has a more recent major version ($($installMajorVersion)) than the user config $($userConfigFileName) ($($userConfigMajorVersion
)). Updated major versions indicate breaking changes. please bring your user config up to date before trying again."
  Write-Host -ForegroundColor Red "IF YOU CHOOSE TO CONTINUE, YOUR INSTALLATION IS HIGHLY LIKELY TO BE IN A BROKEN STATE UNTIL YOU UPDATE YOUR USER CONFIG STRUCTURE (AND POSSIBLY OTHER ITEMS). YOU HAVE BEEN WARNED."
  $userInput = Read-Host "Enter 'y' to update your LazyBlaze from $($userConfigMajorVersion).$($userConfigMinorVersion) to $($installMajorVersion).$($installMinorVersion)"
  if (-not ($userInput -ieq 'y')) {
    Write-Host -ForegroundColor Red "Input did not match 'y', exiting."
    Pause
    Exit
  }
  ReplaceLine -LineRegex $configVersionRegex -NewLine $newVersionLineForConfig -File $userConfigFileName
}
if (($userConfigMajorVersion -eq $installMajorVersion) -and ($userConfigMinorVersion -lt $installMinorVersion)) {
  # User has a config that is slightly out of date, changes are either not breaking or minimally breaking.
  Write-Host "The install config InstallConfig.xml has a more recent minor version ($($installMinorVersion
)) than the user config $($userConfigFileName) ($($userConfigMinorVersion)). Updated minor versions indicate non-breaking changes but you may want to review the example config for small changes."
  $userInput = Read-Host "Enter 'y' to update your LazyBlaze from $($userConfigMajorVersion).$($userConfigMinorVersion) to $($installMajorVersion).$($installMinorVersion)"
  if (-not ($userInput -ieq 'y')) {
    Write-Host -ForegroundColor Red "Input did not match 'y', exiting."
    Pause
    Exit
  }
  ReplaceLine -LineRegex $configVersionRegex -NewLine $newVersionLineForConfig -File $userConfigFileName
}


##########################  Copy Files To Install Location  ################################
function InstallFile {
  param (
    $TargetDir,
    $TargetFileName,
    $SourceFile,
    $FileType,
    $MajorVersion,
    $MinorVersion
  )
  Write-Host -ForegroundColor Yellow "Installing file $($TargetFileName)"
  $targetFile = "$($TargetDir)$($TargetFileName)"
  #if target does not exist then just do copy
  #if target exists, overwrite if true
  #write version comment to top of script

  # create target directory if missing
  if (!(Test-Path -LiteralPath $TargetDir)){
    New-Item -ItemType Directory -Path $TargetDir 
  }
  # check for existing script
  If (test-path -PathType leaf $targetFile){
    Remove-Item -LiteralPath $targetFile
  }
  # update script with the lastest version from source control directory
  Copy-Item -Path $SourceFile -Destination $targetFile
  # add comment to top of script with version info
  switch ($FileType) {
    ".ps1" {
      $lineRegex = ".scriptMajorVersion=.\d*.;.scriptMinorVersion=.\d*.;"
      $newLine = "`$scriptMajorVersion=`"$($MajorVersion)`";`$scriptMinorVersion=`"$($MinorVersion)`";"
    }
    ".psm1" {
      $lineRegex = "#.scriptMajorVersion=.\d*.;.scriptMinorVersion=.\d*.;"
      $newLine = "#`$scriptMajorVersion=`"$($MajorVersion)`";`$scriptMinorVersion=`"$($MinorVersion)`";"
    }
    ".bat" {
      $lineRegex = ":: scriptMajorVersion=.\d*.;scriptMinorVersion=.\d*.;"
      $newLine = ":: scriptMajorVersion=`"$($MajorVersion)`";scriptMinorVersion=`"$($MinorVersion)`";"
    }
    ".jpg" {
      return
    }
    ".reg" {
      return
    }
    default {
      Write-Host -ForegroundColor Red "File $($TargetFileName) was copied but no version header was added, failed to determine file type."
      return
    }
  }
  ReplaceLine -LineRegex $lineRegex -NewLine $newLine -File $targetFile
  return
}

InstallFile -TargetDir $installLocation -TargetFileName "LazyBlaze.bat" -SourceFile ".\FilesToInstall\LazyBlaze.bat" -FileType ".bat" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir $installLocation -TargetFileName "CloneRepos.bat" -SourceFile ".\FilesToInstall\CloneRepos.bat" -FileType ".bat" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion

InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\" -TargetFileName "Main.ps1" -SourceFile ".\FilesToInstall\Main.ps1" -FileType ".ps1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\" -TargetFileName "Backup.ps1" -SourceFile ".\FilesToInstall\Backup.ps1" -FileType ".ps1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\" -TargetFileName "CloneRepos.ps1" -SourceFile ".\FilesToInstall\CloneRepos.ps1" -FileType ".ps1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion

InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\PowershellModules\" -TargetFileName "BackupConfigFile.psm1" -SourceFile ".\FilesToInstall\PowershellModules\BackupConfigFile.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\PowershellModules\" -TargetFileName "CleanForEnvVar.psm1" -SourceFile ".\FilesToInstall\PowershellModules\CleanForEnvVar.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\PowershellModules\" -TargetFileName "CloneGitRepo.psm1" -SourceFile ".\FilesToInstall\PowershellModules\CloneGitRepo.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\PowershellModules\" -TargetFileName "DeleteDirectory.psm1" -SourceFile ".\FilesToInstall\PowershellModules\DeleteDirectory.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\PowershellModules\" -TargetFileName "ExcludeFromBackblaze.psm1" -SourceFile ".\FilesToInstall\PowershellModules\ExcludeFromBackblaze.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\PowershellModules\" -TargetFileName "IsAdmin.psm1" -SourceFile ".\FilesToInstall\PowershellModules\IsAdmin.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\PowershellModules\" -TargetFileName "MoveShortcuts.psm1" -SourceFile ".\FilesToInstall\PowershellModules\MoveShortcuts.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\PowershellModules\" -TargetFileName "PopulateConfigFile.psm1" -SourceFile ".\FilesToInstall\PowershellModules\PopulateConfigFile.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\PowershellModules\" -TargetFileName "RemoveBrokenShortcuts.psm1" -SourceFile ".\FilesToInstall\PowershellModules\RemoveBrokenShortcuts.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\PowershellModules\" -TargetFileName "ReplaceLine.psm1" -SourceFile ".\FilesToInstall\PowershellModules\ReplaceLine.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\PowershellModules\" -TargetFileName "SetConfigValue.psm1" -SourceFile ".\FilesToInstall\PowershellModules\SetConfigValue.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion

InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\IncludedWallpapers\" -TargetFileName "space.jpg" -SourceFile ".\wallpapers\space.jpg" -FileType ".jpg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion

InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\IncludedRegistrySettings\" -TargetFileName "DisableOneDriveSync.reg" -SourceFile ".\registrysettings\DisableOneDriveSync.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\IncludedRegistrySettings\" -TargetFileName "DisableSearchBoxWebResults.reg" -SourceFile ".\registrysettings\DisableSearchBoxWebResults.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\IncludedRegistrySettings\" -TargetFileName "DisableUAC.reg" -SourceFile ".\registrysettings\DisableUAC.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\IncludedRegistrySettings\" -TargetFileName "DisableWindowsCopilot.reg" -SourceFile ".\registrysettings\DisableWindowsCopilot.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\IncludedRegistrySettings\" -TargetFileName "EnableDarkMode.reg" -SourceFile ".\registrysettings\EnableDarkMode.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\IncludedRegistrySettings\" -TargetFileName "FixOneDriveDirectories.reg" -SourceFile ".\registrysettings\FixOneDriveDirectories.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\IncludedRegistrySettings\" -TargetFileName "UpdateConsoleLockDisplayOffTimeout.reg" -SourceFile ".\registrysettings\UpdateConsoleLockDisplayOffTimeout.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\IncludedRegistrySettings\" -TargetFileName "WindowsExplorerShowFileExtensions.reg" -SourceFile ".\registrysettings\WindowsExplorerShowFileExtensions.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)LazyBlazeScripts\IncludedRegistrySettings\" -TargetFileName "WindowsExplorerShowHiddenFiles.reg" -SourceFile ".\registrysettings\WindowsExplorerShowHiddenFiles.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion


##########################  Stop Logging  ################################
if ($logStarted -like "True") {
  Stop-Transcript
}


##########################  Success Message  ################################
Write-Host -ForegroundColor Green "Execution of script $($globalPrimaryScriptName) successfully finished."
Pause