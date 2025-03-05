:: Version info will be inserted by install script
:: scriptMajorVersion="";scriptMinorVersion="";
@ECHO OFF
SET ThisScriptsDirectory=%~dp0
SET PowerShellScriptPath=%ThisScriptsDirectory%Scripts\Main.ps1
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File """"%PowerShellScriptPath%"""" -workingDirectory """"%ThisScriptsDirectory%""" ' -Verb RunAs}";