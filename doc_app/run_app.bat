@echo off
set PATH=C:\dev\nodejs;%PATH%
cd /d "%~dp0"
echo Starting PC Word 365 Editor Desktop App...
call npm run electron:dev
