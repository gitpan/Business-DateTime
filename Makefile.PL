use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    NAME         => 'Business::DateTime',
    VERSION_FROM => 'lib/Business/DateTime.pm', # finds \$VERSION
    AUTHOR       => 'Bob Stockdale (stocks@cpan.org)',
    ABSTRACT     => 'Business DateTime calculations.',
    PREREQ_FATAL => 1,
    PREREQ_PM    => {
                        'DateTime'         => undef,
                        'Params::Validate' => undef,
                    },
);
