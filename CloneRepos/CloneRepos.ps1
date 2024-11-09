param (
  $workingDirectory
)

$PrimaryScriptName = "CloneRepos.ps1"
$requireAdmin = "False"


##########################  Fix Working Directory  ################################
# If launching as admin from a .bat file it will default the working directory to system32
# so we need to pass what the working directory should be as a parameter
$currentWorkingDirectory = (Get-Item .).FullName
if ($null -ne $workingDirectory -and (-not($workingDirectory -like $currentWorkingDirectory))) {
  Write-Host -ForegroundColor Yellow "Setting working directory to '$workingDirectory'"
  Set-Location $workingDirectory
}


##########################  Confirm We Can Find SharedFunctionsAndChecks.ps1  ################################
if (!(test-path -PathType leaf .\LocalConfig.xml)){
  Write-Host -ForegroundColor Red "$($PrimaryScriptName) script must be run from within the local config directory, exiting."
  Pause
  Exit
}
$tmpConfig = [xml](Get-Content .\LocalConfig.xml)
if ($tmpConfig.settings.repolocation -like $null) {
  Write-Host -ForegroundColor Red "$($PrimaryScriptName) script requires repolocation to be set in LocalConfig.xml, exiting."
  Pause
  Exit
}
$tmpSharedFunctionsAndChecksFile = "$($tmpConfig.settings.repolocation)SharedFunctionsAndChecks.ps1"
if (!(test-path -PathType leaf $tmpSharedFunctionsAndChecksFile)) {
  Write-Host -ForegroundColor Red "$($PrimaryScriptName) script requires repolocation in LocalConfig.xml to point to an up to date lazyblaze repository in order to access SharedFunctionsAndChecks.ps1, exiting."
  Pause
  Exit
}


##########################  Run SharedFunctionsAndChecks.ps1  ################################
# Execute script in the current session context, variables are shared between the scripts
. $tmpSharedFunctionsAndChecksFile
if ($globalExit -like "True") {
  Pause
  Exit
}
if (-not($ranSharedFunctionsAndChecks -like "True")) {
  Write-Host -ForegroundColor Red "SharedFunctionsAndChecks.ps1 script did not finish successfully, exiting."
  Pause
  Exit
}


# Verify script is NOT running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin -notlike "False") {
  Write-Host -ForegroundColor Red "Script must NOT be run as administrator, exiting."
  Pause
  Exit
}


##########################  Clone Git Repositories  ################################
# (Can be run multiple times)
$totalGitClones = $config.settings.gitrepositories.SelectNodes("./gitrepo[(@skip='False')]").count
if ($totalGitClones -gt 0){
  Write-Host -ForegroundColor Yellow "Clone Git Repositories..."
}
$currentGitClone = 0
foreach ($gitrepo in $config.settings.gitrepositories.gitrepo) {
  if ($gitrepo.skip -like "True") {
    continue
  }
  $currentGitClone++
  $cleanedId = CleanForEnvVar -Dirty "$($gitrepo.dest)$($gitrepo.name)"
  $gitCloneEnvVarName = "NMSS_CLONEGITREPO_$($cleanedId)"
  $cloneComplete = [Environment]::GetEnvironmentVariable($gitCloneEnvVarName, 'User')
  Write-Host -ForegroundColor Yellow  "Cloning git repository ($($currentGitClone)/$($totalGitClones)) '$($gitrepo.name)' (source: '$($gitrepo.url)') from config"
  if ($cloneComplete -like "COMPLETE"){
    Write-Host -ForegroundColor Green "Clone Git Repository '$($gitrepo.name)' already completed according to environment variable. Skipping."
    continue
  }
  CloneGitRepo -URL $gitrepo.url -DestinationParentDir $gitrepo.dest -LocalName $gitrepo.name
  if ($LASTEXITCODE -eq 0) {
    Write-Host -ForegroundColor Green "$($gitrepo.name) successfully cloned."
    [Environment]::SetEnvironmentVariable($gitCloneEnvVarName, 'COMPLETE', 'User')
  }
  else {
    Write-Host -ForegroundColor Red "$($gitrepo.name) clone failed"
  }
}
if ($totalGitClones -gt 0){
  Write-Host -ForegroundColor Green "Finished Clone Git Repositories."
}


##########################  Add Git Repositories To Github Desktop  ################################
# (Can be run multiple times)
if ($config.settings.addrepostogithubdesktop -like "True"){
  $totalGitRepos = $config.settings.gitrepositories.SelectNodes("./gitrepo[(@skip='False')]").count
  if ($totalGitClones -gt 0){
    Write-Host -ForegroundColor Yellow "Add Git Repositories To Github Desktop..."
  }
  $currentGitRepo = 0
  foreach ($gitrepo in $config.settings.gitrepositories.gitrepo) {
    if ($gitrepo.skip -like "True") {
      continue
    }
    $currentGitRepo++
    $cleanedId = CleanForEnvVar -Dirty "$($gitrepo.dest)$($gitrepo.name)"
    $gitCloneEnvVarName = "NMSS_ADDGITREPOGHDESK_$($cleanedId)"
    $addComplete = [Environment]::GetEnvironmentVariable($gitCloneEnvVarName, 'User')
    Write-Host -ForegroundColor Yellow "Adding git repository ($($currentGitRepo)/$($totalGitRepos)) '$($gitrepo.name)' to Github Desktop"
    if ($addComplete -like "COMPLETE"){
      Write-Host -ForegroundColor Green "Clone Git Repository '$($gitrepo.name)' already completed according to environment variable. Skipping."
      continue
    }
    Write-Host "Press Enter to launch Github Desktop with the repositoy pre-filled in the Add Local Repository prompt..."
    Pause
    # Note: this does not wait on the user interacting with Github Desktop, hence the Pause...
    github "$($gitrepo.dest)$($gitrepo.name)" 
    [Environment]::SetEnvironmentVariable($gitCloneEnvVarName, 'COMPLETE', 'User')
    Write-Host -ForegroundColor Green "Git Repo '$($gitrepo.name)' Added To Github Desktop."
  }
  if ($totalGitClones -gt 0){
    Write-Host -ForegroundColor Green "Finished Add Git Repositories To Github Desktop."
  }
}


##########################  Stop Logging  ################################
if ($logStarted -like "True") {
  Stop-Transcript
}


##########################  Success Message  ################################
Write-Host -ForegroundColor Green "Execution of script $($PrimaryScriptName) successfully finished."
Pause