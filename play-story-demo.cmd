@echo off
setlocal
if not "%~1"=="" set "MIXI_GODOT=%~1"
if not defined MIXI_GODOT for /f "delims=" %%G in ('where godot.exe 2^>nul') do set "MIXI_GODOT=%%G"
if not defined MIXI_GODOT if exist "%LOCALAPPDATA%\Temp\mixi-godot-validation\Godot_v4.7.2-stable_win64.exe" set "MIXI_GODOT=%LOCALAPPDATA%\Temp\mixi-godot-validation\Godot_v4.7.2-stable_win64.exe"
if not defined MIXI_GODOT set "MIXI_GODOT=C:\Users\Admin\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%MIXI_GODOT%" (
  echo Godot not found. Drag your Godot executable onto this file, or set MIXI_GODOT.
  pause
  exit /b 1
)
start "" "%MIXI_GODOT%" --path "%~dp0." -- --demo --demo-full --no-title --map=hn_pho_co
