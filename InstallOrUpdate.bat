@ECHO OFF
SET ThisScriptsDirectory=%~dp0
SET PowerShellScriptPath=%ThisScriptsDirectory%Installer\Install.ps1
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File """"%PowerShellScriptPath%"""" -workingDirectory """"%ThisScriptsDirectory%""" ' -Verb RunAs}";