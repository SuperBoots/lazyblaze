# Version info will be inserted by install script
$scriptMajorVersion="";$scriptMinorVersion="";


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
