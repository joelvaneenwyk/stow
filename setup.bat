@echo off

call "%~dp0tools\make-clean.bat"
call "%~dp0tools\install-dependencies.bat"
call "%~dp0tools\make-stow.bat"
