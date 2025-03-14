# Version info will be inserted by install script
#$scriptMajorVersion="";$scriptMinorVersion="";

<#
 .Synopsis
  Move shortcuts from one folder to another

.Description
  Take all the shortcuts in one directory and move them to a different directory

.Parameter SourceDir
  The directory of the existing shortcuts to be moved.

.Parameter TargetDir
  The directory that the shortcuts should be moved to.

.Example
  MoveShortcuts -SourceDir "C:\Users\McLovin\Desktop\" -TargetDir "C:\Users\McLovin\Shortcuts\"
#>
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


Export-ModuleMember -Function MoveShortcuts