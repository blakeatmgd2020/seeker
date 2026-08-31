@echo off
rem Launch Hidden Hollow with the portable Godot 4.7.1 install.
rem The trailing dot keeps %~dp0's backslash from escaping the closing quote.
start "" "C:\Users\blake\Downloads\Godot_v4.7.1\Godot_v4.7.1-stable_win64.exe" --path "%~dp0."
