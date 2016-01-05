package Devel::QuickCover;

use strict;
use warnings;

use XSLoader;

our $VERSION = '0.300001';

XSLoader::load( 'Devel::QuickCover', $VERSION );

my %DEFAULT_CONFIG = (
    nostart          => 0,      # Don't start gathering coverage information on import
    nodump           => 0,      # Don't dump the coverage report at the END of the program
    output_directory => "/tmp", # Write report to that directory
    metadata         => {}    , # Additional context information
);
our %CONFIG;

sub import {
    my ($class, @opts) = @_;

    die "Invalid argument to import, it takes key-value pairs. FOO => BAR" if 1 == @opts % 2;
    my %options = @opts;

    %CONFIG = %DEFAULT_CONFIG;
    for (keys %options) {
        if (exists $DEFAULT_CONFIG{$_}) {
            $CONFIG{$_} = delete $options{$_};
        }
    }

    if (keys %options > 0) {
        die "Invalid import option(s): " . join(',', keys %options) ;
    }

    if (!$CONFIG{'nostart'}) {
        Devel::QuickCover::start();
    }
}

END {
    if (!$CONFIG{'nodump'}) {
        Devel::QuickCover::end();
    }
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Devel::QuickCover - Quick & dirty code coverage for Perl

=head1 VERSION

Version 0.300000

=head1 SYNOPSIS

    use Devel::QuickCover;
    my $x = 1;
    my $z = 1 + $x;

=head1 DESCRIPTION

The following program sets up the coverage hook on C<use> and dumps
a report (to C</tmp> by default) at the end of execution.

    use Devel::QuickCover;
    my $x = 1;
    my $z = 1 + $x;

The following program sets up the coverage hook on C<start()> and
dumps a report to C<some_dir> on C<end()>, at which point
the coverage hook gets uninstalled. So in this case, we only get
coverage information for C<bar()>. We also get the specified metadata
in the coverage information.

    use Devel::QuickCover (
      nostart => 1,
      nodump => 1,
      output_directory => "some_dir/",
      metadata => { git_tag = "deadbeef" });

    foo();
    Devel::QuickCover::start();
    bar();
    Devel::QuickCover::end();
    baz();

For now, we support calling C<start()> only once.

=head1 AUTHORS

=over 4

=item * Gonzalo Diethelm C<< gonzus AT cpan DOT org >>

=item * Andreas Guðmundsson C<< andreasg AT nasarde DOT org >>

=item * Andrei Vereha C<< avereha AT cpan DOT org >>

=back

=head1 THANKS

=over 4

=item * Mattia Barbon

=item * p5pclub

=back
