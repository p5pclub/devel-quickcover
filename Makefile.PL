use 5.008005;
use ExtUtils::MakeMaker;
WriteMakefile(
    NAME           => 'Devel::QuickCover',
    VERSION_FROM   => 'lib/devel/quickcover.pm',
    ABSTRACT_FROM  => 'lib/devel/quickcover.pm',
    PREREQ_PM      => {
        'Test::More'          => 0,
        'Exporter'            => '5.57',
        'XSLoader'            => 0,
    },
    AUTHOR         => 'Gonzalo Diethelm (gonzus@cpan.org)',
    LIBS           => [''],
    DEFINE         => '-DGMEM_CHECK',
#    DEFINE         => '-DGLOG_SHOW',
#    DEFINE         => '-DGMEM_CHECK=1 -DGLOG_SHOW',
    INC            => '-I.',
    OBJECT         => '$(O_FILES)',
);

# Add -Wall to CCFLAGS without overwriting the defaults
package MY;
sub cflags {
    my $self   = shift;
    my $cflags = $self->SUPER::cflags(@_);
    my @cflags = split /\n/, $cflags;

    $self->{CCFLAGS} .= ' -Wall';
    foreach (@cflags) {
        $_ = "CCFLAGS = $self->{CCFLAGS}" if /^CCFLAGS/;
    }
    return $self->{CFLAGS} = join("\n", @cflags) . "\n";
}
