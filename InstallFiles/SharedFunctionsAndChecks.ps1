# Version info $scriptMajorVersion and $scriptMajorVersion will be inserted above this line by install script

##########################  Admin Check  ################################
if ($globalRequireAdmin -like "True") {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($isAdmin -notlike "True") {
      Write-Host -ForegroundColor Red "Script must be run as administrator, exiting."
      $globalExit = "True"
      Exit
    }
}

##########################  Locate Self  ################################
# Figure out where this script is being executed from
if (test-path -PathType leaf .\Config.xml){
    $someConfig = [xml](Get-Content .\Config.xml)
    if ($someConfig.settings.mylocation -like "CodeRepo") {
        # This script is executing from the code repository
        $inRepo = "True"
        $repoDirectory = "$(Get-Location)\"
    }
}
$configLocationXmlFileName = "Location.xml"
if (test-path -PathType leaf ".\$($configLocationXmlFileName)"){
    $someConfig = [xml](Get-Content .\Location.xml)
    if ($someConfig.settings.mylocation -like "LocalConfig") {
        # This script is executing from the local config directory
        $inLocalConfig = "True"
        $configDir = "$(Get-Location)\"
    }
}
# Exit if script is not running in repo or config directory
if ((-not ($inRepo -like "True")) -and (-not ($inLocalConfig -like "True"))) {
    Write-Host -ForegroundColor Red "Script appears to not be running in the lazyblaze repository or the local config folder. All scripts in this collection must be run from one of these locations."
    $globalExit = "True"
    Exit
}


##################  Populate A Value In LocalConfig.xml  ########################
function SetConfigValue {
  param (
    $Key,
    $Value,
    $MyLocalConfigFile,
    $OnlySetIfEmpty = "True"
  )
  $attempts = 0
  $maxAttempts = 10
  while ($attempts -lt $maxAttempts) {
    try {
      $attempts++
      $MyLocalConfigXml = [xml](Get-Content $MyLocalConfigFile)
      $currentXmlValue = $MyLocalConfigXml.settings."$Key"
      $regex = "\s*<$($Key)>.*</$($Key)>"
      $existingstring = Select-String -Path $MyLocalConfigFile -Pattern $regex
      if (-not ($null -ne $existingstring)) {
        Write-Host -ForegroundColor Red "SetConfigValue failed to find an entry for $($Key) in local config while attempting to set to '$($Value)', make sure the setting <$($Key)></$($Key)> exists in your local config. Exiting..."
        $globalExit = "True"
        Return
      }
      if ($currentXmlValue -clike "$Value") {
        Return
      }
      if (( -not ($currentXmlValue -like "")) -and $OnlySetIfEmpty -like "True") {
        Write-Host "Skipping changing config value of $($Key) from '$($currentXmlValue)' to '$($Value)' because OnlySetIfEmpty is True..."
        Return
      }
      (Get-Content $MyLocalConfigFile) -replace $regex, "  <$($Key)>$($Value)</$($Key)>" | Set-Content $MyLocalConfigFile
      Write-Host -ForegroundColor Green "Set config value for $($Key) to '$($Value)'"
      Return
    } catch [System.Exception] {
      $_
      if ($attempts -gt ($maxAttempts - 1)) {
        Write-Host -ForegroundColor Red "Set Config has reached max allowable attempts (of $($maxAttempts)), abandoning ship."
        $globalExit = "True"
        Exit
      }
      Write-Host -ForegroundColor Red "Set Config <$($Key)></$($Key)> to '$($Value)' attempt $($attempts) failed, sleeping 1 second before attempting again."
      Start-Sleep -Seconds 1
    }
  }
}


##########################  Get User Specific Values From System ################################
$sysUserName = $env:USERNAME
$sysMachineName = Invoke-Expression -Command 'hostname'


##########################  Get/Create Local Config File  ################################
# Check for an existing LocalConfig.xml file and use the example if one doesn't already exist
$configFileName = "LocalConfig.xml"
if ($inRepo -like "True") {
    $repoConfig = [xml](Get-Content Config.xml)
    $configDir = $repoConfig.settings.directory
    $configFullDest = "$($configDir)$($configFileName)"
    if (!(Test-Path -LiteralPath $configDir)) {
        New-Item -ItemType Directory -Path $configDir
    }
    if (!(test-path -PathType leaf $configFullDest)){
        Copy-Item -Path ".\ExampleLocalConfig\$($configFileName)" -Destination $configFullDest
        SetConfigValue -Key 'repolocation' -Value $repoDirectory -MyLocalConfigFile $configFullDest -OnlySetIfEmpty "True"
        SetConfigValue -Key 'username' -Value $sysUserName -MyLocalConfigFile $configFullDest -OnlySetIfEmpty "True"
        SetConfigValue -Key 'machinename' -Value $sysMachineName -MyLocalConfigFile $configFullDest -OnlySetIfEmpty "True"
        Write-Host -ForegroundColor Red "A new local config file has been added to your system. Please review and update the contents of $($configFullDest) before continuing."
        Write-Host -ForegroundColor Red "This script will not run until the 'reviewed' property has been set to True at the bottom of the new config file $($configFullDest)"
        $globalExit = "True"
        Exit
    }
    # Check repo location in config
    $configToUpdate = [xml](Get-Content $configFullDest)
    if ($configToUpdate.settings.repolocation -notlike $repoDirectory){
      Write-Host -ForegroundColor Red "settings.repolocation in local config needs to match the repository you're running these scripts from."
      Write-Host -ForegroundColor Red "settings.repolocation is currently '$($configToUpdate.settings.repolocation)' but your repository appears to be '$($repoDirectory)'."
      Write-Host -ForegroundColor Red "Please update settings.repolocation to match the repository directory that these scripts are being run from."
      Write-Host -ForegroundColor Red "Script is now exiting."
      $globalExit = "True"
      Exit
    }
}
if ($inLocalConfig -like "True") {
    $configFullDest = "$($configDir)$($configFileName)"
}


##########################  Logging  ################################
$date = (Get-Date).ToString("yyyy-MM-dd_HHmmss")
$logFile = "$($configDir)Logs\$($date)_$($globalPrimaryScriptName)_log.txt"
Start-Transcript -Path $logFile
$logStarted = "True"


##########################  Create ConfigLocationXmlFile  ################################
$configLocationXmlFile = "$($configDir)$($configLocationXmlFileName)"
if (!(test-path -PathType leaf $configLocationXmlFile)) {
  Write-Host "Creating '$($configLocationXmlFileName)' file in local configuration directory '$($configDir)' for the purpose of figuring out where the fuck we are."
  $xmlsettings = New-Object System.Xml.XmlWriterSettings
  $xmlsettings.Indent = $true
  $xmlWriter = [System.XML.XmlWriter]::Create($configLocationXmlFile, $xmlsettings)
  $xmlWriter.WriteStartElement("settings") 
  $xmlWriter.WriteElementString("mylocation", "LocalConfig")
  $xmlWriter.WriteEndElement()
  $xmlWriter.Flush()
  $xmlWriter.Close()
}


##########################  Load Config  ################################
$config = [xml](Get-Content $configFullDest)
$userFromConfig = $config.settings.username
$userdir = "C:\Users\$($userFromConfig)\"


##########################  Checking Config Version  ################################
# This section exists to protect users from running a newer version of the scripts with an older local config
# file when there have been breaking changes to the codebase. This can happen very easily if you're keeping your
# local LazyBlaze repository up to date.
$repoDirectoryInConfig = $config.settings.repolocation
$exampleLocalConfigFullName = "$($repoDirectoryInConfig)ExampleLocalConfig\LocalConfig.xml"
$exampleLocalConfig = [xml](Get-Content $exampleLocalConfigFullName)
$majorVersion_ExampleConfig = $exampleLocalConfig.settings.version.major
$minorVersion_ExampleConfig = $exampleLocalConfig.settings.version.minor
$majorVersion_LocalConfig = $config.settings.version.major
$minorVersion_LocalConfig = $config.settings.version.minor
if (($majorVersion_LocalConfig -gt $majorVersion_ExampleConfig) -or (($majorVersion_LocalConfig -eq $majorVersion_ExampleConfig) -and ($minorVersion_LocalConfig -gt $minorVersion_ExampleConfig))) {
  # User has somehow ende up with a local config version that's more recent than the repo that the scripts are being run from.
  Write-Host -ForegroundColor Red "You've somehow got a version of your local config that's more recent than the version in source control. I'm going to be honest, I'm confused. I give up."
  $globalExit = "True"
  Exit
}
if ($majorVersion_LocalConfig -lt $majorVersion_ExampleConfig) {
  # User has a local config that is old enough that the current repo has breaking changes
  Write-Host -ForegroundColor Red "ERROR: The example config $($exampleLocalConfigFullName) has a more recent major version ($($majorVersion_ExampleConfig)) than the local config $($configFullDest) ($($majorVersion_LocalConfig
)). Updated major versions indicate breaking changes, please bring your local config up to date before trying again."
  $globalExit = "True"
  Exit
}
if (($majorVersion_LocalConfig -eq $majorVersion_ExampleConfig) -and ($minorVersion_LocalConfig -lt $minorVersion_ExampleConfig)) {
  # User has a local config that is slightly out of date, default behavior is to block script execution but this can be overridden by the minorblocking setting in the local config.
  Write-Host -ForegroundColor Yellow "Warning: The example config $($exampleLocalConfigFullName) has a more recent minor version ($($minorVersion_ExampleConfig
)) than the local config $($configFullDest) ($($minorVersion_LocalConfig)). Updated minor versions indicate non-breaking changes but you may want to review the example config."
  if ($null -eq $config.settings.version.minorblocking -or $config.settings.version.minorblocking -like "True") {
    Write-Host -ForegroundColor Red "Exiting script. If you want to allow this script to continue with minor version differences set the minorblocking property to False in your local config $($configFullDest)"
    $globalExit = "True"
    Exit
  }
}


##########################  Verify User Has Reviewed Config  ################################
if ($config.settings.reviewed -notlike "True") {
  Write-Host -ForegroundColor Red "This script will not run until the 'reviewed' property has been set to True at the bottom of the new config file $($configDir)$($configFileName)"
  $globalExit = "True"
  Exit
}


##########################  Check/Populate Core Config Values  ################################
$generatedNewConfigValue = "False"
$coreConfigValueMismatch = "False"
$repolocationInConfig = $config.settings.repolocation
$actualRepoDirectory = "NotFound"
if ($inRepo -like "True") {
  $actualRepoDirectory = "$(Get-Location)\"
}
if ($null -eq $repolocationInConfig -or $repolocationInConfig -like "") {
  SetConfigValue -Key 'repolocation' -Value $actualRepoDirectory -MyLocalConfigFile $configFullDest -OnlySetIfEmpty "True"
  Write-Host -ForegroundColor Green "Automatically setting missing value in local config, Name: repolocation, Value: $($actualRepoDirectory)"
  $generatedNewConfigValue = "True"
}
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
  $globalExit = "True"
  Exit
}
if ($generatedNewConfigValue -like "True") {
  Write-Host -ForegroundColor Red "Check/Populate core config values has populated at least one missing value. It is recommended that you review the populated value before running again. Exiting."
  $globalExit = "True"
  Exit
}


##########################  Verify Repo Location In Config Is Correct  ################################
$repoDirectory = $config.settings.repolocation
if ($null -eq $repoDirectory -or $repoDirectory -like "") {
  Write-Host "Local Config $($configFullDest) has blank or missing setting for repolocation."
  $repoConfigFail = "True"
}
if (-not (test-path -PathType leaf "$($repoDirectory)Config.xml")) {
  Write-Host "Failed to find repository config file  $($repoDirectory)Config.xml"
  $repoConfigFail = "True"
}
$repoConfigXml = [xml](Get-Content "$($repoDirectory)Config.xml")
if ($repoConfigXml.settings.mylocation -notlike "CodeRepo") {
  Write-Host "Expected mylocation in Config.xml in repo to be 'CodeRepo' but found:  '$($repoConfigXml.settings.mylocation)'"
  $repoConfigFail = "True"
}
if ($repoConfigFail -like "True") {
  Write-Host -ForegroundColor Red "repolocation validation failed. repolocation in $($configFullDest) should be the full path to the lazyblaze git repository on your machine."
  $globalExit = "True"
  Exit
}


##################################################################################
##########################  Function Definitions  ################################
function DeleteDirectory {
  param (
    $Directory
  )
  Write-Host "Deleting directory '$Directory'"
    if (Test-Path -LiteralPath $Directory) {
      try {
        Remove-Item -LiteralPath $Directory -Recurse -ErrorAction 'Stop'
      }
      catch {
        Write-Host "ERROR: delete directory failed for '$Directory'"
      }
    }
    Write-Host "Directory '$Directory' not found"
}

function ExcludeFromBackblaze {
  param (
    $Directory
  )
  $attempts = 0
  $maxAttempts = 10
  while ($attempts -lt $maxAttempts) {
    try {
      $attempts++
      $backblazeconfigfile = "C:\ProgramData\Backblaze\bzdata\bzinfo.xml"
      $newLine = "    <bzdirfilter dir=`"$($Directory)\`" whichfiles=`"none`" />"
      $existingstring = Select-String -Path $backblazeconfigfile -Pattern $newLine -SimpleMatch
      if ($existingstring -eq $null) {
        Write-Host "Adding to Backblaze Exclusion list '$newLine'"
        (Get-Content $backblazeconfigfile) | 
          Foreach-Object {
            $_ # send the current line to output
            if ($_ -match "<do_backup") 
            {
              #Add Lines after the selected pattern 
              $newLine
            }
          } | Set-Content $backblazeconfigfile
      } else {
        Write-Host "Skipping Backblaze exclusion addition, list already contains '$newLine'"
      }
      Return
    } catch [System.Exception] {
      if ($attempts -gt ($maxAttempts - 1)) {
        Write-Host -ForegroundColor Red "Maximum allowable number of attempts of $($maxAttempts) has been reached, abandoning ship."
        $globalExit = "True"
        Exit
      }
      Write-Host -ForegroundColor Red "Backblaze config update attempt $($attempts) failed, sleeping 1 second before attempting again."
      Start-Sleep -Seconds 1
    }
  }
}

function PopulateConfigFile {
  param (
    $FileName,
    $SourceDir,
    $TargetDir
  )
  $TargetFile = "$($TargetDir)$($FileName)"
  $SourceFile = "$($SourceDir)$($FileName)"
  if (!(test-path -PathType leaf $SourceFile)) {
    Write-Host "No file found at $($SourceFile), skipping"
    return
  }
  If (test-path -PathType leaf $TargetFile) {
    Remove-Item -LiteralPath $TargetFile
  }
  if (!(Test-Path -LiteralPath $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir 
  }
  Copy-Item -Path $SourceFile -Destination $TargetFile
}

function MoveShortcuts {
  param (
    $SourceDir,
    $TargetDir
  )

  If (!(test-path -PathType container $TargetDir)){
    New-Item -ItemType Directory -Path $TargetDir
  }
  $files = Get-ChildItem $SourceDir -Filter *.lnk
  foreach ($filename in $files){
    $destination = "$($TargetDir)$($filename)"
    If (test-path -PathType leaf $destination){
      Remove-Item -LiteralPath $destination
    }
    Move-Item -Path "$($SourceDir)$($filename)" -Destination $destination
  }
}

function RemoveBrokenShortcuts {
  param (
    $Directory
  )
  $Shortcuts = Get-ChildItem -Recurse $Directory -Include *.lnk -Force
  $Shell = New-Object -ComObject WScript.Shell
  foreach ($Shortcut in $Shortcuts) {
    $target = $shell.CreateShortcut($Shortcut).TargetPath
    if ($target -eq "") {
      # Test-Path will blow up if it gets an empty string
      Remove-Item -LiteralPath $Shortcut
      continue
    }
    $targetExists = Test-Path "$target"
    If ($targetExists -eq $false) {
      Remove-Item -LiteralPath $Shortcut
    }
  }
}

function UpdateLocalFileCopy {
  param (
    $TargetDir,
    $FileName,
    $SourceDir,
    $MyConfig,
    $AddVersionHeader,
    $MajorVersion,
    $MinorVersion
  )
  $targetFile = "$($TargetDir)$($FileName)"
  $sourceFile = "$($SourceDir)$($FileName)"
  #if target does not exist then just do copy
  #if target exists, overwrite if true
  #write version comment to top of script

  # create target directory if missing
  if (!(Test-Path -LiteralPath $TargetDir)){
    New-Item -ItemType Directory -Path $TargetDir 
  }
  # check for existing script
  If (test-path -PathType leaf $targetFile){
    if ($MyConfig.settings.updatescripts -like "True") {
      Remove-Item -LiteralPath $targetFile
    } else {
      Write-Host "Skipping update of '$($targetFile)', updatescripts not enabled in config."
      return
    }
  }
  # update script with the lastest version from source control directory
  Copy-Item -Path $sourceFile -Destination $targetFile
  if ($AddVersionHeader -like "True") {
    # add comment to top of script with version info
    $header = "#MajorVersion=$($MajorVersion),MinorVersion=$($MinorVersion)"
    $header | Set-Content "$($targetFile).temp"
    Get-Content $targetFile -ReadCount 5000 |
      Add-Content "$($targetFile).temp"
    Remove-item $targetFile
    Rename-Item "$($targetFile).temp" -NewName $targetFile
  }
}

function CloneGitRepo {
  param (
    $URL,
    $DestinationParentDir,
    $LocalName
  )
  $FullDest = "$($DestinationParentDir)$($LocalName)"
  # Make sure the parent directory exists
  if (!(Test-Path -LiteralPath $DestinationParentDir)){
    Write-Host "Creating missing directory $($DestinationParentDir)"
    New-Item -ItemType Directory -Path $DestinationParentDir 
  }
  # Delete the repository if it already exists
  if (Test-Path -LiteralPath $FullDest){
    DeleteDirectory -Directory $FullDest
  }
  git clone $URL $FullDest
}

function BackupConfigFile {
  param (
    $FileName,
    $SourceDir,
    $TargetDir
  )

  $TargetFile = "$($TargetDir)$($FileName)"
  $SourceFile = "$($SourceDir)$($FileName)"
  If (test-path -PathType leaf $SourceFile){
    If (test-path -PathType leaf $TargetFile){
      Remove-Item -LiteralPath $TargetFile
    }
    if (!(Test-Path -LiteralPath $TargetDir)){
      New-Item -ItemType Directory -Path $TargetDir 
    }
    Copy-Item -Path $SourceFile -Destination $TargetFile
  }
}

function CleanForEnvVar {
  param (
    $Dirty
  )

  $cleaned = $Dirty -replace '\.'
  $cleaned = $Dirty -replace '\:'
  $cleaned = $Dirty -replace '\\'
  return $cleaned
}
########################  End Function Definitions  ##############################
##################################################################################


##########################  Copy Files to Local Config Directory  ################################
# Move some files into the local config directory for doing things like daily backups and cloning git repos.
# If you set AddVersionHeader to True it basically stamps the major and minor version from the example local 
# config in the repo at the top of the file, essentially marking the version of the repository that they are from.
# The headers are formatted as a comment in powershell, but they will break .bat files.
UpdateLocalFileCopy -TargetDir $configDir -FileName "Backup.ps1" -SourceDir "$($repoDirectory)ScheduledBackup\" -MyConfig $config -AddVersionHeader "True" -MajorVersion $majorVersion_ExampleConfig -MinorVersion $minorVersion_ExampleConfig
UpdateLocalFileCopy -TargetDir $configDir -FileName "CloneRepos.ps1" -SourceDir "$($repoDirectory)CloneRepos\" -MyConfig $config -AddVersionHeader "True" -MajorVersion $majorVersion_ExampleConfig -MinorVersion $minorVersion_ExampleConfig
UpdateLocalFileCopy -TargetDir $configDir -FileName "CloneRepos.bat" -SourceDir "$($repoDirectory)CloneRepos\" -MyConfig $config -AddVersionHeader "False" -MajorVersion $majorVersion_ExampleConfig -MinorVersion $minorVersion_ExampleConfig
UpdateLocalFileCopy -TargetDir $configDir -FileName "SharedFunctionsAndChecks.ps1" -SourceDir $($repoDirectory) -MyConfig $config -AddVersionHeader "True" -MajorVersion $majorVersion_ExampleConfig -MinorVersion $minorVersion_ExampleConfig


$ranSharedFunctionsAndChecks = "True"
