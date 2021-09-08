@echo off

setlocal EnableExtensions EnableDelayedExpansion

perl "%~dp0initialize-cpan-config.pl"

:: Already installed as part of Strawberry Perl but install/update regardless.
call cpan -i -T App::cpanminus

::
:: Install dependencies. Note that 'Inline::C' requires 'make' and 'gcc' to be installed. It
:: is recommended to install the following MSYS2 packages:
::
::      - mingw-w64-x86_64-make
::      - mingw-w64-x86_64-gcc
::      - mingw-w64-x86_64-binutils
::
call cpanm --installdeps --sudo --notest "%~dp0..\"
