@echo off

set STOW_ROOT=%~dp0../
set VERSION=2.3.2
set PERL=perl
set PMDIR=${prefix:-}/share/perl5/site_perl
set USE_LIB_PMDIR=NA

:: if ! PERL5LIB=$($PERL -V | awk '/@INC/ {p=1; next} (p==1) {print $1}' | grep "$PMDIR" | head -n 1); then
::     echo "ERROR: Failed to check installed Perl libraries."
::     PERL5LIB="$PMDIR"
:: fi
::
:: echo "# Perl modules will be installed to $PMDIR"
:: echo "#"
:: if [ -n "$PERL5LIB" ]; then
::     USE_LIB_PMDIR=""
::     echo "# This is in $PERL's built-in @INC, so everything"
::     echo "# should work fine with no extra effort."
:: else
::     USE_LIB_PMDIR="use lib \"$PMDIR\";"
::     echo "# This is *not* in $PERL's built-in @INC, so the"
::     echo "# front-end scripts will have an appropriate \"use lib\""
::     echo "# line inserted to compensate."
:: fi
::
:: echo "#"
:: echo "# PERL5LIB: $PERL5LIB"

call :edit "%STOW_ROOT%\bin\chkstow"
call :edit "%STOW_ROOT%\bin\stow"
call :edit "%STOW_ROOT%\lib\Stow.pm"
call :edit "%STOW_ROOT%\lib\Stow\Util.pm"
exit /b 0

:edit
    set input_file=%~1.in
    set output_file=%~1

    :: This is more explicit and reliable than the config file trick
    perl -p -e "s/\@PERL\@/%PERL%/g;" -e "s/\@VERSION\@/%VERSION%/g;" -e "s/\@USE_LIB_PMDIR\@/%USE_LIB_PMDIR%/g;" "%input_file%" >"%output_file%"
exit /b 0
