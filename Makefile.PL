use 5.008005;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME           => 'Devel::QuickCover',
    VERSION_FROM   => 'lib/Devel/QuickCover.pm',
    ABSTRACT_FROM  => 'lib/Devel/QuickCover.pm',
    PREREQ_PM      => {
        'Exporter'            => '5.57',
        'XSLoader'            => 0,
        'JSON::XS'            => 0,
        'File::Slurp'         => 0,
    },
    TEST_REQUIRES  => {
        'Test::More'            => 0,
        'Test::Builder::Module' => 0,
        'File::Temp'            => 0,
    },
    AUTHOR         => 'Gonzalo Diethelm (gonzus@cpan.org)',
    LIBS           => [''],
#    DEFINE         => '-DGMEM_CHECK',
#    DEFINE         => '-DGLOG_SHOW',
#    DEFINE         => '-DGMEM_CHECK=1 -DGLOG_SHOW',
#    OPTIMIZE       => '-g',
    INC            => '-I.',
    OBJECT         => '$(O_FILES)',
);

# Add -Wall to CCFLAGS without overwriting the defaults
package MY;
sub cflags {
    my $self   = shift;
    my $cflags = $self->SUPER::cflags(@_);
    my @cflags = split /\n/, $cflags;

    $self->{CCFLAGS} .= ' -Wall';                # Flag all warnings
    # $self->{CCFLAGS} .= ' -std=c99';             # Compile according to C99 standard
    $self->{CCFLAGS} .= ' -std=c89';             # Compile according to C89 standard
    # $self->{CCFLAGS} .= ' -pedantic';            # Be pedantic about warnings - no GNU extensions
    $self->{CCFLAGS} .= ' -D_XOPEN_SOURCE=700';  # Needed for localtime_r()

    foreach (@cflags) {
        $_ = "CCFLAGS = $self->{CCFLAGS}" if /^CCFLAGS/;
    }
    return $self->{CFLAGS} = join("\n", @cflags) . "\n";
}
