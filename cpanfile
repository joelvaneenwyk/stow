requires 'perl', '>=5.006';

use constant IS_WIN32 => $^O eq 'MSWin32';

requires 'Carp';
requires 'Inline::C';
requires 'IO::File';
requires 'IO::Scalar';
requires 'Parse::RecDescent';
requires 'YAML';
requires 'CPAN::DistnameInfo';
requires 'Module::Build';

if (IS_WIN32) {
    requires 'Win32::Mutex';
}

recommends 'App::cpanminus';

on 'test' => sub {
    requires 'Test::Output';
    requires 'Test::More';
    requires 'Test::Exception';
    requires 'TAP::Formatter::JUnit';
    requires 'Devel::Cover::Report::Coveralls';
};

on 'develop' => sub {
    recommends 'Perl::LanguageServer';
    recommends 'Perl::Critic';
    recommends 'Perl::Tidy';
};
