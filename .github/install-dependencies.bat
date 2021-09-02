@echo off

setlocal EnableExtensions EnableDelayedExpansion

perl -MCPAN -e "my $c = 'CPAN::HandleConfig'; $c->load(doit => 1, autoconfig => 1); $c->edit(prerequisites_policy => 'follow'); $c->edit(build_requires_install_policy => 'yes'); $c->commit"

:: Install dependencies
call cpan -i -T YAML Test::Output Test::More CPAN::DistnameInfo

:: Install dev dependencies
call cpan -i -T Perl::LanguageServer Perl::Critic Perl::Tidy
