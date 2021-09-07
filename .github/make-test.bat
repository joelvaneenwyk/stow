@echo off

call "%~dp0make-stow.bat"
prove -I t/ -I bin/ -I lib/ --timer --formatter TAP::Formatter::JUnit t/
