# Version info will be inserted by install script
#$scriptMajorVersion="";$scriptMinorVersion="";

<#
 .Synopsis
  Remove broken shortcuts from a directory

.Description
  Remove shorcuts that either don't have a target set or are set to a target that doesn't exist. 
  Will remove from child directories as well.
  I added this because Windows 11 and/or backblaze was bringing broken shortcut along when I restored.

.Parameter Directory
  The directory that broken shortcuts should be removed from.

.Example
  RemoveBrokenShortcuts -Directory "C:\Users\McLovin\Desktop\"
#>
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


Export-ModuleMember -Function RemoveBrokenShortcuts