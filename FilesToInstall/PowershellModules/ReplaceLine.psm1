# Version info will be inserted by install script
#$scriptMajorVersion="";$scriptMinorVersion="";

<#
 .Synopsis
  Replaces a line in a file.

.Description
  Uses a regular expression to find a line in a file and replace it with a supplied value.

.Parameter LineRegex
  Regular Expression used to match the line.

.Parameter NewLine
  The new line text that should be inserted.

.Parameter File
  The file that the line should be replaced in.

.Example
   ReplaceLine -LineRegex ".scriptMajorVersion=\d*;.scriptMinorVersion=\d*;" -NewLine "`$scriptMajorVersion=011;`$scriptMajorVersion=002" -File ".\LazyBlaze.bat"
#>
function ReplaceLine {
  param (
    $LineRegex,
    $NewLine,
    $File
  )
  $attempts = 0
  $maxAttempts = 10
  while ($attempts -lt $maxAttempts) {
    try {
      $attempts++
      $existingstring = Select-String -Path $File -Pattern $LineRegex
      if (-not ($null -ne $existingstring)) {
        Write-Host -ForegroundColor Red "ReplaceLine failed to find an entry for $($LineRegex) in $($File), Exiting..."
        $globalExit = "True"
        Return
      }
      (Get-Content $File) -replace $LineRegex, $NewLine | Set-Content $File
      Write-Host -ForegroundColor Green "Replaced line '$($existingstring)' with '$($NewLine)' in $($File)"
      Return
    } catch [System.Exception] {
      $_
      if ($attempts -gt ($maxAttempts - 1)) {
        Write-Host -ForegroundColor Red "ReplaceLine has reached max allowable attempts (of $($maxAttempts)), abandoning ship."
        $globalExit = "True"
        Exit
      }
      Write-Host -ForegroundColor Red "ReplaceLine attempt $($attempts) failed, sleeping 1 second before attempting again."
      Start-Sleep -Seconds 1
    }
  }
}


Export-ModuleMember -Function ReplaceLine