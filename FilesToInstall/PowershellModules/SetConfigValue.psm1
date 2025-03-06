# Version info will be inserted by install script
#$scriptMajorVersion="";$scriptMinorVersion="";

<#
 .Synopsis
  Sets a value in the main LazyBlaze config file.

.Description
  Uses a regular expression to find a line in a file and replace it with a supplied value. Returns true if successful.

.Parameter Key
  The name of the xml property to set.

.Parameter Value
  The value that the xml property should be set to.

.Parameter MyLocalConfigFile
  The full path to the user's LazyBlaze config file

.Parameter OnlySetIfEmpty
  If true, the config value will only be modified if the existing value is empty. Defaults to true. 

.Example
   SetConfigValue -Key 'machinename' -Value 'Goose' -MyLocalConfigFile 'C:\LazyBlaze'
#>
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


Export-ModuleMember -Function SetConfigValue