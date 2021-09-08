requires 'perl', '>=5.006';

requires 'Carp';
requires 'Parse::RecDescent';
requires 'Inline::C';
requires 'IO::File';
requires 'IO::Scalar';
requires 'YAML';
requires 'CPAN::DistnameInfo';

recommends 'App::cpanminus';

on 'configure' => sub {
    requires 'Module::Build';
    requires 'Inline::C';
    requires 'Parse::RecDescent';
};

on 'test' => sub {
    requires 'Test::Output';
    requires 'Test::More';
    requires 'Test::Exception';
    requires 'Devel::Cover::Report::Coveralls';
    requires 'TAP::Formatter::JUnit';
};

on 'develop' => sub {
    recommends 'Perl::LanguageServer';
    recommends 'Perl::Critic';
    recommends 'Perl::Tidy';
};
