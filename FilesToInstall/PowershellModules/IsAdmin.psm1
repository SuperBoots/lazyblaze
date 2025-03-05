# Version info will be inserted by install script
#$scriptMajorVersion="";$scriptMinorVersion="";

<#
 .Synopsis
  Check if script is being run as admin

.Description
  Uses Security.Principal.WindowsPrincipal to check if current script is being run as administrator. Returns $true or $false

.Example
   IsAdmin
#>
function IsAdmin {
  $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
  return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


Export-ModuleMember -Function IsAdmin