@echo off

setlocal EnableExtensions EnableDelayedExpansion

perl -MCPAN "%~dp0initialize-cpan-config.pl"

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
call cpanm --install --notest ^
    YAML Test::Output Test::More Test::Exception ^
    CPAN::DistnameInfo Module::Build Parse::RecDescent Inline::C ^
    Perl::LanguageServer Perl::Critic Perl::Tidy ^
    Devel::Cover::Report::Coveralls TAP::Formatter::JUnit
