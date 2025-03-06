# Version info will be inserted by install script
#$scriptMajorVersion="";$scriptMinorVersion="";

<#
 .Synopsis
  Copies a file to a destination

.Description
  Intended for taking things like config files that have been backed up previously using LazyBlaze and 

.Parameter FileName
  The filename of the file to be copied, including extension.

.Parameter SourceDir
  The location of the file to be copied

.Parameter TargetDir
  The location to copy the file to

.Example
  PopulateConfigFile -FileName "myspecialconfig.xml" -SourceDir ".\backups\" -TargetDir "C:\Users\McLovin\SuperSpecialPlace\"
#>
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


Export-ModuleMember -Function PopulateConfigFile