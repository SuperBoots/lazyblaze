# LazyBlaze
Created by Dan Partington
https://buymeacoffee.com/danpartington

The goal of this project is to minimize the time and effort it takes to go from a brand new Windows 11 install to a fully functional PC with the programs you want to use installed and configured.

This project is designed to take advantage of Backblaze computer backups to get a machine as close as possible to the state it was in before while still retaining the wonderful cleaning power of a disc reformat and Windows reinstall. (Note: I have not tested lazyblaze with Backblaze B2 Cloud Storage, but a ticket has been added to the backlog to investigate compatibility)

This project will work perfectly fine even if you're not using Backblaze, just make sure skipsection="True" for backblazeclean in your config and ignore the Backblaze specific steps in the instructions.

# Simplified Usage Instructions
1. Run `InstallOrUpdate.bat` to install or update LazyBlaze (from somewhere on your C:\ drive).
    * You will be prompted with the target install location, press 'y' to install
    * Default install location is `C:\Users\(username)\OneDrive\LazyBlaze_(machinename)\`
    * If you want to change the install location, press 'n' to cancel the install, then open Installer/InstallConfig.xml and modify settings under installdirectory, then run installer again.
1. Open the folder that LazyBlaze was installed to, see default above
    * I will refer to this folder as 'your Lazyblaze instance' going forward
    * You should see the folder `LazyBlazeScripts` and the files `LazyBlaze.bat` and `CloneRepos.bat` and `Config.xml`
1. In your LazyBlaze instance: Make updates to `Config.xml` to define which programs to install (among other things)
    * Example Winget config entries for program installations that have been tested can be found in this repository in `\ExampleConfigEntries\VerifiedWingetInstalls.txt`
    * Example registry edits can be found in this repository in `\registrysettings\`, they are also copied to the install location under `\LazyBlazeScripts\IncludedRegistrySettings\`
    * Update `<reviewed>False</reviewed>` to `<reviewed>True</reviewed>` at the bottom of the `Config.xml` file, if you don't update this the script won't install anything.
1. In your LazyBlaze instance: Run `LazyBlaze.bat`, there are various safety checks in place so watch for the script to stop and prompt you to take some action. The common behavior if everything is configured correctly then the Main.ps1 will be executed in it's entirety.
1. (optional) In your LazyBlaze instance: Run `CloneRepos.bat` to clone the git repositories you've defined in your local config
    * For more information see "Clone Code Repositories" below
1. Done!

## Understanding Your LazyBlaze Instance (default `C:\Users\(username)\OneDrive\LazyBlaze_(machinename)\`)
LazyBlaze uses a very basic "installer" for two main reasons. One is to provide some safety net around updating your instance of LazyBlaze, and the other reason is to simplify development by keeping user-specific changes out of the code repository.
The default location that your LazyBlaze instance will be installed to is `C:\Users\(username)\OneDrive\LazyBlaze_(machinename)\`, you can change it by updating `Installer\InstallConfig.xml` in the root of this repository before you run the scripts.

The file you will want to get familiar with in your LazyBlaze instance is `Config.xml`. The `Config.xml` file allows LazyBlaze to require almost zero user interaction while it's running by specifying all your preferences and selections ahead of time in one location. When you first install your LazyBlaze instance `Config.xml` will just have some default values in it, these are mostly to show what the structure looks like of the various options.

Some features of LazyBlaze can use files that you provide, for example "Set Wallpaper" will by default use `(your lazyblaze instance)\LazyBlazeScripts\IncludedWallpapers\space.jpg` as your wallpaper image, but you can put whatever image you want in the IncludedWallpapers folder and update `Config.xml` to use your custom wallpaper.

The idea here is that you get your LazyBlaze instance all set up so that it's got the app installs that you want and all the details are how you like them. Then, if you get a new PC or you need to wipe your existing PC, you can just have your LazyBlaze instance backed up, and put your LazyBlaze instance on the new machine and run it and you should end up coming as close as possible to replicating the set up of your old machine.

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

## Run LazyBlaze.bat file (this is where the magic happens)
1. *(wait until after Backblaze restore is complete before running LazyBlaze.bat)*
1. Run LazyBlaze.bat in your LazyBlaze instance
1. Pay attention to prompts, if there are any changes you need to make the script will tell you, and then you'll need to re-run LazyBlaze.bat.
1. *Depending on what features you have enabled and the number of apps you're installing, this can be a long process. I've generally tried to keep anything that requires user interaction at the very beginning, so you should be able to walk away once you've confirmed it's chugging along.*

## *Special Instructions - Removing Files from Backblaze Backup*
*There are three main reasons I've needed to remove files from Backblaze backups, either they're causing issues with running the scripts, causing system instability, or they're just excessively large and it's making your restore process take forever. Whatever the reason, the method for removing files from your backup is the same. (and unfortunately kind of a pain because Backblaze doesn't make removing files from a backup easy)*
1. *Identify the folders/files that are adding too much to storage size and add them to the <backblazeclean> section of your Config.xml in your BackBlaze instance.* 
1. *At this point there should be two backups on backblaze.com for this machine, one that is the 'real' backup and one that was created today (because a new one is created whenever you install Backblaze). Identify the old (real) backup and the new (empty) backup*
1. *If you've managed to keep the new backup empty, or a least keep any of the files you're trying to remove out of it, then you can just let the new backup be the backup going forward. In this case, skip the rest of 'Removing Files from Backblaze Backup - Part 1'*
1. *Only follow these sub-steps if you need to throw away the new backup and start a new one*
    1. *On backblaze.com delete the new (created today) backup*
    1. *Uninstall Backblaze (via Add/Remove Programs) and then restart computer*
    1. *Re-Install Backblaze AND IMMEDIATELY OPEN THE BACKBLAZE CONTROL PANEL AND PAUSE THE BACKUP AND/OR KILL THE BACKBLAZE APP.* 
        * *(It will be trying to create a new backup from scratch and if you don't pause the backup it'll just start backing up everything. You can go look at anything that got uploaded on backblaze.com, as long as the files you're tring to remove didn't get uploaded yet you should be good.)*
1. *Run (or re-run) LazyBlaze.bat with `<backblazeclean skipsection="False">` in order to re-populate the Backblaze exclusions list that got reset when Backblaze was re-installed*
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
1. *If using `Add Git Repositories To Github Desktop` option (you should, it's awesome) then follow these sub-steps, otherwise just skip to 'Run CloneRepos.bat'* 
    * *You'll need to launch the Github Desktop application and get logged in.*
    * *Before running CloneRepos.bat, make sure the Github Desktop window is actually open*
        * *If you DON'T have Github Desktop open when you run Run CloneRepos.bat then Github Desktop will launch for each local repository add, then you will need to close Github Desktop between each repository to continue*
        * *If you DO have Github Desktop open when you run Run CloneRepos.bat then Github Desktop will just open a prompt for each local repository add, then you just hit 'Add Repository' to continue*
    * *After all the repositories are cloned the script will loop through the list again and pause on each one, waiting for you to prompt before launching Github Desktop with the local repository location filled in.*
    * *You'll need to click the `Add repository` button in GitHub Desktop once for each repository in your config*
1. Run CloneRepos.bat
    * The Git Credentials Manager UI will pop up for any repositories that don't already have creds saved in the manager.

## Sign in to apps
I highly suggest that you keep your own detailed list of app logins and manual configurations.

## A list of other similar projects on github
1. [Opendows Tweakers](https://github.com/MarcoRavich/Opendows/blob/main/Tweakers.md#-) (this list is awesome)
1. [Open source tweakers collection discussion](https://github.com/PearPony/Creosynth/discussions/)

