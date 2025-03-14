# Version info will be inserted by install script
#$scriptMajorVersion="";$scriptMinorVersion="";

<#
 .Synopsis
  Clones a git repository from the web to a specified location on your machine.

.Description
  Uses git clone to clone a git repository to a specified directory. 
  If the directory doens't exist it will be created.
  This should NOT be run as administrator since then it will create complications 
  with managing the git repos in github desktop if you want to go that route.

.Parameter URL
  The URL to the repository on the web, on github.com it would be the "HTTPS Clone URL"

.Parameter DestinationParentDir
  The parent directory that the repository should be cloned into.

.Parameter LocalName
  The actual directory name that should be used for the local repository.

.Example
  CloneGitRepo -URL "https://github.com/SuperBoots/lazyblaze.git" -DestinationParentDir "C:\Code\Personal\Dan\" -LocalName "lazyblaze"
#>
function CloneGitRepo {
  param (
    $URL,
    $DestinationParentDir,
    $LocalName
  )
  $FullDest = "$($DestinationParentDir)$($LocalName)"
  # Make sure the parent directory exists
  if (!(Test-Path -LiteralPath $DestinationParentDir)){
    Write-Host "Creating missing directory $($DestinationParentDir)"
    New-Item -ItemType Directory -Path $DestinationParentDir 
  }
  # Delete the repository if it already exists
  if (Test-Path -LiteralPath $FullDest){
    DeleteDirectory -Directory $FullDest
  }
  git clone $URL $FullDest
}


Export-ModuleMember -Function CloneGitRepo