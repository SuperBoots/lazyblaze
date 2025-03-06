# Version info will be inserted by install script
#$scriptMajorVersion="";$scriptMinorVersion="";

<#
 .Synopsis
  Remove problematic characters.

.Description
  Intended for taking a potential environment vairable name and removing problematic characters from it.

.Parameter Dirty
  The desired environment variable name before being cleaned

.Example
  CleanForEnvVar -Dirty "myawesome:environment.variable\thing"
#>
function CleanForEnvVar {
  param (
    $Dirty
  )

  $cleaned = $Dirty -replace '\.'
  $cleaned = $Dirty -replace '\:'
  $cleaned = $Dirty -replace '\\'
  return $cleaned
}


Export-ModuleMember -Function CleanForEnvVar