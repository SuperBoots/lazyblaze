param (
  $workingDirectory
)

$globalPrimaryScriptName = "CloneRepos"
$globalRequireAdmin = "False"


##########################  Fix Working Directory  ################################
# If launching as admin from a .bat file it will default the working directory to system32
# so we need to pass what the working directory should be as a parameter
$currentWorkingDirectory = (Get-Item .).FullName
if ($null -ne $workingDirectory -and (-not($workingDirectory -like $currentWorkingDirectory))) {
  Write-Host -ForegroundColor Yellow "Setting working directory to '$workingDirectory'"
  Set-Location $workingDirectory
}


##########################  Run SharedFunctionsAndChecks.ps1  ################################
# Execute script in the current session context, variables are shared between the scripts
. ".\SharedFunctionsAndChecks.ps1"
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
# If repos are cloned while running as administrator it causes issues adding them to github desktop
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin -notlike "False") {
  Write-Host -ForegroundColor Red "Script must NOT be run as administrator, exiting."
  Pause
  Exit
}


##########################  Clone Git Repositories  ################################
# (Can be run multiple times)
if ($config.settings.gitrepositories.skipsection -like "False") {
  Write-Host "Section: Clone Git Repositories (gitrepositories in config), starting..."
  $totalGitClones = $config.settings.gitrepositories.SelectNodes("./gitrepo[(@skip='False')]").count
  if ($totalGitClones -gt 0) {
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
  Write-Host "Section: Clone Git Repositories (gitrepositories in config), finished"
}
else {
  Write-Host "Section: Clone Git Repositories (gitrepositories in config), skipping"
}


##########################  Add Git Repositories To Github Desktop  ################################
# (Can be run multiple times)
if ($config.settings.gitrepositories.skipsection -like "False" -and $config.settings.gitrepositories.options.addrepostogithubdesktop -like "True") {
  Write-Host "Section: Add Git Repositories To Github Desktop (gitrepositories in config), starting..."
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
  Write-Host "Section: Add Git Repositories To Github Desktop (gitrepositories in config), finished"
}
else {
  Write-Host "Section: Add Git Repositories To Github Desktop (gitrepositories in config), skipping"
}


##########################  Stop Logging  ################################
if ($logStarted -like "True") {
  Stop-Transcript
}


##########################  Success Message  ################################
Write-Host -ForegroundColor Green "Execution of script $($globalPrimaryScriptName) successfully finished."
Pause