# Version info will be inserted by install script
#$scriptMajorVersion="";$scriptMinorVersion="";

<#
 .Synopsis
  Delete a directory if it exists

.Description
  Uses Remove-Item to delete a directory and any child directories

.Parameter Directory
  The full path of the directory to delete

.Example
  DeleteDirectory -Directory "C:\DeleteMe"
#>
function DeleteDirectory {
  param (
    $Directory
  )
  Write-Host "Deleting directory '$Directory'"
  if (Test-Path -LiteralPath $Directory) {
    try {
      Remove-Item -LiteralPath $Directory -Recurse -ErrorAction 'Stop'
    }
    catch {
      Write-Host "ERROR: delete directory failed for '$Directory'"
    }
  }
  Write-Host "Directory '$Directory' not found"
}


Export-ModuleMember -Function DeleteDirectory