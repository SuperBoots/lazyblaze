param (
  $workingDirectory
)

$globalPrimaryScriptName = "Install"
$globalRequireAdmin = "True"


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


##########################  Start Logging  ################################
$date = (Get-Date).ToString("yyyy-MM-dd_HHmmss")
$logFile = ".\Logs\$($date)_$($globalPrimaryScriptName)_log.txt"
Start-Transcript -Path $logFile
$logStarted = "True"


##########################  Determine Install Location  ################################
$installLocation = $installConfig.settings.installdirectory.fulldirectory
if ($installConfig.settings.installdirectory.options.useuserdirectory -like "True") {
  $installLocation = "$($env:USERPROFILE)\$($installConfig.settings.installdirectory.userdirectory)"
}
Write-Host -ForegroundColor Yellow "LazyBlaze will be installed to '$($installLocation)'"
$userInput = Read-Host "Enter 'y' to continue installation"
if (-not ($userInput -ieq 'y')) {
  Write-Host -ForegroundColor Red "Input did not match 'y', exiting."
  Pause
  Exit
}


##########################  Validate Install Version  ################################
$installMajorVersion = $installConfig.settings.version.major
$installMinorVersion = $installConfig.settings.version.minor
$installMinorBlocking = $installConfig.settings.version.options.minorblocking
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


##########################  Add User Config  ################################
$userConfigFileName = "$($installLocation)Config.xml"
if (-not (test-path -PathType leaf $userConfigFileName)) {
  Write-Host -ForegroundColor Yellow "Existing config not found, creating '$($userConfigFileName)'"
  if (!(Test-Path -LiteralPath $installLocation)) {
    New-Item -ItemType Directory -Path $installLocation 
  }
  Copy-Item -Path ".\FilesToInstall\Config.xml" -Destination $userConfigFileName
  $attempts = 0
  $maxAttempts = 10
  while ($attempts -lt $maxAttempts) {
    try {
      $attempts++
      $regex = '\s*<version major=.* minor=.*></version>'
      $existingstring = Select-String -Path $userConfigFileName -Pattern $regex
      if (-not ($null -ne $existingstring)) {
        Write-Host -ForegroundColor Red "Failed to find an entry for version in starter config. Exiting..."
        Pause
        Exit
      }
      $newVersionLine = "  <version major=""$($installMajorVersion)"" minor=""$($installMinorVersion)""></version>"
      (Get-Content $userConfigFileName) -replace $regex, $newVersionLine | Set-Content $userConfigFileName
      Write-Host -ForegroundColor Green "Set user config version info to $($newVersionLine)"
      break
    } catch [System.Exception] {
      $_
      if ($attempts -gt ($maxAttempts - 1)) {
        Write-Host -ForegroundColor Red "Set Config Version has reached max allowable attempts (of $($maxAttempts)), abandoning ship."
        Pause
        Exit
      }
      Write-Host -ForegroundColor Red "Set Config Version attempt $($attempts) failed, sleeping 1 second before attempting again."
      Start-Sleep -Seconds 1
    }
  }
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
  Write-Host -ForegroundColor Red "ERROR: The installer has a more recent major version ($($installMajorVersion)) than the user config $($userConfigFileName) ($($userConfigMajorVersion
)). Updated major versions indicate breaking changes, please bring your user config up to date before trying again."
  Pause
  Exit
}
if (($userConfigMajorVersion -eq $installMajorVersion) -and ($userConfigMinorVersion -lt $installMinorVersion)) {
  # User has a config that is slightly out of date, default behavior is to block installation but this can be overridden by the minorblocking setting in the install config.
  Write-Host -ForegroundColor Yellow "Warning: The install config InstallConfig.xml has a more recent minor version ($($installMinorVersion
)) than the user config $($userConfigFileName) ($($userConfigMinorVersion)). Updated minor versions indicate non-breaking changes but you may want to review the example config."
  if ($null -eq $installMinorBlocking -or $installMinorBlocking -like "True") {
    Write-Host -ForegroundColor Red "Exiting script. If you want to allow this script to continue with minor version differences set the minorblocking property to False in the install config InstallConfig.xml"
    Pause
    Exit
  }
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

InstallFile -TargetDir "$($installLocation)Scripts\" -TargetFileName "Main.ps1" -SourceFile ".\FilesToInstall\Main.ps1" -FileType ".ps1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)Scripts\" -TargetFileName "SharedFunctionsAndChecks.ps1" -SourceFile ".\FilesToInstall\SharedFunctionsAndChecks.ps1" -FileType ".ps1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)Scripts\" -TargetFileName "Backup.ps1" -SourceFile ".\FilesToInstall\Backup.ps1" -FileType ".ps1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)Scripts\" -TargetFileName "CloneRepos.ps1" -SourceFile ".\FilesToInstall\CloneRepos.ps1" -FileType ".ps1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion

InstallFile -TargetDir "$($installLocation)Scripts\PowershellModules\" -TargetFileName "IsAdmin.psm1" -SourceFile ".\FilesToInstall\PowershellModules\IsAdmin.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)Scripts\PowershellModules\" -TargetFileName "ReplaceLine.psm1" -SourceFile ".\FilesToInstall\PowershellModules\ReplaceLine.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)Scripts\PowershellModules\" -TargetFileName "SetConfigValue.psm1" -SourceFile ".\FilesToInstall\PowershellModules\SetConfigValue.psm1" -FileType ".psm1" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion

InstallFile -TargetDir "$($installLocation)wallpapers\" -TargetFileName "space.jpg" -SourceFile ".\wallpapers\space.jpg" -FileType ".jpg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion

InstallFile -TargetDir "$($installLocation)registrysettings\" -TargetFileName "DisableOneDriveSync.reg" -SourceFile ".\registrysettings\DisableOneDriveSync.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)registrysettings\" -TargetFileName "DisableSearchBoxWebResults.reg" -SourceFile ".\registrysettings\DisableSearchBoxWebResults.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)registrysettings\" -TargetFileName "DisableUAC.reg" -SourceFile ".\registrysettings\DisableUAC.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)registrysettings\" -TargetFileName "DisableWindowsCopilot.reg" -SourceFile ".\registrysettings\DisableWindowsCopilot.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)registrysettings\" -TargetFileName "EnableDarkMode.reg" -SourceFile ".\registrysettings\EnableDarkMode.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)registrysettings\" -TargetFileName "FixOneDriveDirectories.reg" -SourceFile ".\registrysettings\FixOneDriveDirectories.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)registrysettings\" -TargetFileName "UpdateConsoleLockDisplayOffTimeout.reg" -SourceFile ".\registrysettings\UpdateConsoleLockDisplayOffTimeout.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)registrysettings\" -TargetFileName "WindowsExplorerShowFileExtensions.reg" -SourceFile ".\registrysettings\WindowsExplorerShowFileExtensions.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion
InstallFile -TargetDir "$($installLocation)registrysettings\" -TargetFileName "WindowsExplorerShowHiddenFiles.reg" -SourceFile ".\registrysettings\WindowsExplorerShowHiddenFiles.reg" -FileType ".reg" -MajorVersion $installMajorVersion -MinorVersion $installMinorVersion


##########################  Stop Logging  ################################
if ($logStarted -like "True") {
  Stop-Transcript
}


##########################  Success Message  ################################
Write-Host -ForegroundColor Green "Execution of script $($globalPrimaryScriptName) successfully finished."
Pause