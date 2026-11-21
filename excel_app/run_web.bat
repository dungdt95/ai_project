@echo off
title PC Excel Editor 365 (Web Dev Mode)
cd /d "%~dp0"
set "PATH=C:\dev\nodejs;%PATH%"
echo [Excel PC] Khoi dong phien ban Web...
npm run dev
