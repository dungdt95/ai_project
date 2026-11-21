@echo off
set PATH=C:\dev\nodejs;%PATH%
cd /d "%~dp0"
echo Starting PC Word 365 Editor Web Dev Server...
call npm run dev
