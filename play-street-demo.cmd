@echo off
setlocal
set "MIXI_GODOT=C:\Users\Admin\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if not exist "%MIXI_GODOT%" (
  echo Godot not found. Update MIXI_GODOT in this file to your Godot executable.
  pause
  exit /b 1
)
start "" "%MIXI_GODOT%" --path "%~dp0." -- --demo --pilot --street-demo
