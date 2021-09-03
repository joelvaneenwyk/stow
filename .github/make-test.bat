@echo off

call "%~dp0make-stow.bat"
::@prove -I t/ -I bin/ -I lib/ --formatter TAP::Formatter::JUnit t/
@prove -I t/ -I bin/ -I lib/ t/make_links.t
