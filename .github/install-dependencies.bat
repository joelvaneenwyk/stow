@echo off

setlocal EnableExtensions EnableDelayedExpansion

perl -MCPAN "%~dp0init-config.pl"

:: Already installed as part of Strawberry Perl but install/update regardless
call cpan -i -T App::cpanminus

:: Install dependencies
call cpanm --install --notest YAML Test::Output Test::More Test::Exception CPAN::DistnameInfo Module::Build Parse::RecDescent Inline::C

:: Install dev dependencies
call cpanm --install --notest Perl::LanguageServer Perl::Critic Perl::Tidy Devel::Cover::Report::Coveralls
