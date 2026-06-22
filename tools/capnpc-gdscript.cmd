@echo off
rem capnpc-gdscript.cmd - Windows shim for the Cap'n Proto -> GDScript plugin.
rem
rem capnp invokes this with the CodeGeneratorRequest on stdin and CWD = the
rem output dir. We capture that CWD, spool the binary stdin to a tempfile (Godot
rem cannot read stdin), and run the headless Godot plugin.
rem
rem Requires environment:
rem   CAPNGODO_GODOT    path to the Godot 4.6+ binary (godot.exe)
rem   CAPNGODO_PROJECT  path to the capngodo project
rem
rem NOTE: capnp on Windows may not spawn a .cmd plugin via `-o gdscript`. If it
rem fails to find this shim, use the shimless 2-step from the README instead
rem (capnp compile -o- ... > request.bin, then run plugin_main.gd directly).

setlocal
if "%CAPNGODO_GODOT%"=="" ( echo set CAPNGODO_GODOT to your Godot binary 1>&2 & exit /b 1 )
if "%CAPNGODO_PROJECT%"=="" ( echo set CAPNGODO_PROJECT to the capngodo project dir 1>&2 & exit /b 1 )

set "OUT_DIR=%CD%"
set "REQ=%TEMP%\capnpc-gdscript-%RANDOM%%RANDOM%.bin"

rem Copy raw stdin -> tempfile (PowerShell handles binary; cmd cannot).
powershell -NoProfile -Command "$i=[Console]::OpenStandardInput(); $o=[IO.File]::Create($env:REQ); $i.CopyTo($o); $o.Close()"
if errorlevel 1 ( echo failed to read stdin 1>&2 & exit /b 1 )

"%CAPNGODO_GODOT%" --headless --quiet --path "%CAPNGODO_PROJECT%" --script "res://addons/capngodo/codegen/plugin_main.gd" -- "%OUT_DIR%" "%REQ%" 1>&2
set "RC=%ERRORLEVEL%"
del "%REQ%" 2>nul
exit /b %RC%
