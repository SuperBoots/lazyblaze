# Version info will be inserted by install script
#$scriptMajorVersion="";$scriptMinorVersion="";

<#
 .Synopsis
  Add new directory to the backblaze backup exclusion list

.Description
  Backblaze uses a config file bzinfo.xml to determine which directories to ignore, this methods adds to the ignore list.

.Parameter Directory
  The directory that should be excluded from backblaze backup

.Example
  ExcludeFromBackblaze -Directory "C:\KeepMeOutOfBackBlaze\"
#>
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


Export-ModuleMember -Function ExcludeFromBackblaze