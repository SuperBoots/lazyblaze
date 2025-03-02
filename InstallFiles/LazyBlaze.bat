:: Version info scriptMajorVersion and scriptMajorVersion will be inserted above this line by install script
@ECHO OFF
SET ThisScriptsDirectory=%~dp0
SET PowerShellScriptPath=%ThisScriptsDirectory%Scripts\Main.ps1
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File """"%PowerShellScriptPath%"""" -workingDirectory """"%ThisScriptsDirectory%""" ' -Verb RunAs}";