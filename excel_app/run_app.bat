@echo off
title PC Excel Editor 365 (Desktop App)
cd /d "%~dp0"
set "PATH=C:\dev\nodejs;%PATH%"
echo [Excel PC] Khoi dong ung dung Excel Desktop...
npx electron .
