@echo off
rem Runs the game on Direct3D 12 instead of Vulkan so Win+Alt+R (Game Bar) can record it.
cd /d "%~dp0"
start "" "C:\Users\denzh\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path . --rendering-driver d3d12
