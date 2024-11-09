# LazyBlaze
Created by Dan Partington

The goal of this project is to minimize the time and effort it takes to go from a brand new Windows 11 install to a fully functional PC with the programs you want to use installed and configured.

This project is designed to take advantage of Backblaze computer backups to get a machine as close as possible to the state it was in before while still retaining the wonderful cleaning power of a disc reformat and Windows reinstall.

This project will work perfectly fine even if you're not using Backblaze, just set usingbackblaze to False in the config and ignore the Backblaze specific steps in the instructions.

## Understanding the local configuration folder `C:\LazyBlazeConfig\`
Once you've cloned the repository for lazyblaze you should be all set to just start following the "Fresh Windows Install Instructions" below, but there's an external folder that will be created by the scripts that you should be aware of. The default location of this folder is `C:\LazyBlazeConfig\`, you can change it by updating `Config.xml` in the root of this repository before you run the scripts, but I'd recommend leaving it as default if possible.

The `C:\LazyBlazeConfig\` folder that gets created will have some values already populated, but the purpose of this folder is to hold values and files that are specific to your machine that the scripts in this repository can use. The most important thing in this directory is LocalConfig.xml, it defines what programs to remove, what programs to install, and generally just lets you pick all your options once and then setup everything with minimal interaction. 

The idea is that you'll run through the setup process once and make a lot of changes to the local config, then once it's in a spot that you like you can save LocalConfig.xml somewhere safe off your machine, or better yet save the whole `C:\LazyBlazeConfig\` folder, and then if you need to rebuild your machine from scratch you can just put your saved config folder back in place and run LazyBlaze.bat to get your environment built out exactly how it was before.

# Fresh Windows Install Instructions
I suggest keeping a document for each of your machines with more specific details to keep your environment as repeatable as possible. My personal instruction documents live in google docs, I have one document per machine. I basically copied these instructions to start and then added details as I went.

## Reinstall Windows
1. Go to Windows System > Recovery > Reset this PC
1. Select “Remove everything”
1. Initiate the reset
1. You may be prompted to confirm that you want to clear the TPM. 
    * The TPM is primarily used to unlock your BitLocker encrypted drive automatically behind the scenes
    * If you're doing a complete system wipe and reinstalling Windows without retaining anything on the disk then you're totally fine to clear the TPM. The TPM was set up for accessing your old data, that data is gone now.
    * If your drive isn't encrypted then it definitely shouldn't matter if you clear the TPM.
    * *If you're still nervous, even if you do clear the TPM on this step and realize that you shouldn't have, if you're using BitLocker and you’ve backed up your BitLocker recovery key you’ll be able to recover your data.*
1. Work your way through the windows install prompts
1. Windows is installed!

## Configure display options (optional)
1. Right click and go to Display Settings
1. Set resolution, set scale, rearrange screens, etc
1. Save changes

## Enable Remote Access (optional)
If you have another machine handy that's already up and running with access to these instructions and/or your password manager then you may want to take a second to enable remote desktop so that you can just keep these instructions open on that machine and copy and paste usernames and passwords from one machine to the other until you've got the password manager all set up on the new machine.

## Restore Files with Backblaze
1. Get the [Backblaze](https://secure.backblaze.com/user_overview.htm) Installer
    * Manually type backblaze password in notepad, you’ll use it at least twice
    * If you have another machine setup on your local network with file sharing, I'd suggest you download the Backblaze installer on that machine and then just pass the installer exe to the new machine.
    * Otherwise, use the default browser to go to backblaze.com and download the installer
    * Log in to backblaze.com and then scroll to the bottm of the Overview page to find the download links.
1. Run the Backblaze installer
    * Select "Install Now"
    * Select "OK" when install is complete
1. Open Backblaze Control Panel
    * Pause backup, it's going to start uploading everything it finds to a new backup that's just going to be deleted soon.
    * Select “Restore Options”
    * Select “Restore App”
    * Sign in
    * Select backup via dropdown (not the one with the current date)
    * Check all files
    * For “Restore files to” select “Same location and overwrite identical files”
    * Press “Restore”

## Random Tasks That Can Be Done While Backblaze Restores Files
1. If you didn't already complete the "Enable Remote Access" step above, then do it now.
1. Check for Windows updates and install them.

## Get the lazyblaze repository onto your machine (after Backblaze restore is complete)
1. If you had the most recent version in your backup that you just restored then you're good to go
1. Otherwise, grab the files from another computer you have up and running or download from github. You don't need to do a git clone or anything, you just need the files, the repository will be overwritten later in the process.
1. If you had your local config folder backed up somewhere, now would be the time to put that back on this machine

## (Restart Computer)
* If using Backblaze:
    * Pause Backblaze backup after reboot is complete

## *Special Instructions - Removing Files from Backblaze Backup - Part 1*
*There are three main reasons I've needed to remove files from Backblaze backups, either they're causing issues with running the scripts, causing system instability, or they're just excessively large and it's making your restore process take forever. Whatever the reason, the method for removing files from your backup is the same.*
1. *Identify the folders/files that are adding too much to storage size and add them to the <backblazeclean> section of the LocalConfig.xml (default location `C:\LazyBlazeConfig\`).* 
1. *At this point there should be two backups on backblaze.com for this machine, one that is the 'real' backup and one that was created today (because a new one is created whenever you install Backblaze). Identify the old (real) backup and the new (empty) backup*
1. *If you've managed to keep the new backup empty, or a least keep any of the files you're trying to remove out of it, then you can just let the new backup be the backup going forward. In this case, skip the rest of 'Removing Files from Backblaze Backup - Part 1'*
1. *You should only be at this step if you need to throw away the new backup and start a new one*
1. *On backblaze.com delete the new (created today) backup*
1. *Uninstall Backblaze (via Add/Remove Programs) and restart computer*
1. *Re-Install Backblaze AND IMMEDIATELY OPEN THE BACKBLAZE CONTROL PANEL AND PAUSE THE BACKUP. It will be trying to create a new backup from scratch and if you don't pause the backup it'll just start backing up everything. You can go look at anything that got uploaded on backblaze.com, as long as the files you're tring to remove didn't get uploaded yet you should be good.*
1. *Continue 'Removing Files from Backblaze Backup - Part 2' after completing the next step*

## Run .bat file to install all applications (after Backblaze restore is complete)
1. Run LazyBlaze.bat in your local lazyblaze directory

## *Special Instructions - Removing Files from Backblaze Backup - Part 2*
*Creating a fresh backup*
1. *Restart the computer*
1. *Let Backblaze populate the new backup, it will show up on backblaze.com as unlicensed with today's date in the name* 
1. *Verify that the new backup on backblaze.com does not include the files that you wanted to remove.*
1. *Deleting the old backup*
    * *Before you delete the old backup, create a restore of it just in case.*
    * *If it's smaller than 500 GB then you can just go to backblaze.com and click 'Restore' on the old backup, leave 'Download' selected, select all files and folders, and scroll to the bottom of the page and click 'Continue with Restore'. This will create a zip file of your backup that will stay on backblaze.com for 7 days before it's deleted.*
    * *Once the restore is finished being created (check the status in 'My Restores' on backblaze.com) you can delete the old backup. On backblaze.com go to 'Preferences', find the old backup (the name you wrote down in 'Removing Files from Backblaze Backup - Part 1') and select 'Delete Backup'*
    * *You may need to go back to the dashboard on backblaze.com and assign your now unused license to the new backup.*
    * *I rename my backups by just removing the day of the month from the date, for example I would rename 'goose_2024_10_31' to just 'goose_2024-10', I find that this makes it easier to keep track of old vs new backups during this process.*
1. *Once the new backup is created I'd suggest doing a full machine reset and starting this process again from the beginning. Alternatively, you could just manually delete the files from your local machine that you're adding to the exclusion and try moving forward.*

## (Restart Computer)
* If using Backblaze:
    * Pause Backblaze backup after reboot is complete

## Inherit Correct Backblaze Backup
1. *Skip the Inherit Correct Backblaze Backup step if you're following the special instructions for removing files from backblaze, in that case you just created a new backup and that's the one you want to keep*
1. Open Backblaze Control Panel
1. Select “Settings”
1. Select “Inherit Backup State”
1. Sign in
1. Select same backup computer you just restored from
1. Select “Inherit Backup”
1. Close settings, go to the main page of the Backblaze Control Panel and resume backup.
1. Go to [Backblaze](https://secure.backblaze.com/user_overview.htm) website, go to “preferences” on the left under computer backup
1. Find the backup that was just created when backblaze was installed and delete it
1. Restart Computer

## (Restart Computer)

## Clone Code Repositories
1. *I'd suggest getting logged into your password manager and browsers before the Clone Code Repositories step.*
1. If using `Add Git Repositories To Github Desktop` option 
    * Then you'll need to launch the Github Desktop application first on your machine and get logged in.
    * (`addrepostogithubdesktop` setting in config)
1. Open local config folder, default is `C:\LazyBlazeConfig\`
1. Run CloneRepos.bat
    * The Git Credentials Manager UI will pop up for any repositories that don't already have creds saved in the manager.
    * *FYI - CloneRepos.ps1 needs to be run from the local config folder because it needs to be in the same directory as the LocalConfig.xml file and it can't be in this repository because this repository will likely be deleted and recreated by the script.*
1. *If using `Add Git Repositories To Github Desktop` option* 
    * *After all the repositories are cloned the script will loop through the list again and pause on each one, waiting for you to prompt before launching Github Desktop with the local repository location filled in.*
    * *You'll need to click the `Add repository` button in GitHub Desktop once for each repository in your config*

## Sign in to apps
I highly suggest that you keep your own detailed list of app logins and manual configurations.

## Any Other apps to manually install
1. [Oculus PC App](https://www.meta.com/help/quest/articles/headsets-and-accessories/oculus-rift-s/install-app-for-link/) 
1. ???

# TO-DO
1. Make run time of the scheduled backup configurable
1. Have Backup task scheduler check to make sure there's not already an existing scheduled task.
1. Add step to verify username and machine name
1. Test scripts on Dev box
1. Test scripts with a custom local config folder selected
1. Consider moving the default location for the local config folder into the user directory
1. Fixed broken postman agent winget install, verify that it actually installed the desktop agent.
1. See if I can get pause/restart/continue working in my scripts?
    * https://stackoverflow.com/questions/15166839/powershell-reboot-and-continue-script
1. When running the 'InstallApps' script you end up with a bunch of open programs piling up on top of eachother, see if there's a reasonable way to kill processes after install is done.
1. Would it be reasonable and/or valuable to put a check to see if the user is running the latest version of the repo from git?
1. Add option to daily backup script to cleanup old files in downloads folder (to keep backup size from growing too large)
1. Test installing PowerToys via winget (added to LocalConfig.xml in source)
    * Set up FancyZones
1. Get OpenVPN Connect set up for work (write down instructions)
