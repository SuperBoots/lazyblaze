# Version info will be inserted by install script
#$scriptMajorVersion="";$scriptMinorVersion="";

<#
 .Synopsis
  Back up a file.

.Description
  Intended for taking things like config files (Terminal options, DBeaver connections) that live in a location that isn't normally 
  backed up, and copying them into the lazyblaze directory for simplified backup and restoration.

.Parameter FileName
  The filename of the file to be backed up, including extension.

.Parameter SourceDir
  The location of the file to be backed up

.Parameter TargetDir
  The location to copy the file to

.Example
  BackupConfigFile -FileName "myspecialconfig.xml" -SourceDir "C:\Users\McLovin\SuperSpecialPlace\" -TargetDir ".\backups\"
#>
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


Export-ModuleMember -Function BackupConfigFile