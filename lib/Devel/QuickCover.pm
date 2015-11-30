package Devel::QuickCover;
use strict;
use warnings;
use XSLoader;
use Data::Dumper;

our $VERSION = '0.11';

XSLoader::load( 'Devel::QuickCover', $VERSION );

my %DEFAULT_CONFIG = (
    nostart          => 0,   # Don't start gathering coverage information on import
    nodump           => 0,   # Don't dump the coverage report at the END of the program
    output_directory => "/tmp", # Write report to that directory
);
our %CONFIG;

our %METADATA;

sub import {
    my ($class, @opts) = @_;

    die "Invalud argument to import, it takes key-value pairs. FOO => BAR" if 1==@opts % 2;
    my %options = @opts;

    %CONFIG = %DEFAULT_CONFIG;
    for (keys %options) {
        if (exists $DEFAULT_CONFIG{$_}) {
            $CONFIG{$_} = delete $options{$_};
        }
    }

    if (keys %options > 0) {
        die "Invalid import option(s): ".join(',',keys %options) ;
    }

    if (not $CONFIG{'nostart'}) {
        Devel::QuickCover::start();
    }
}

sub add_metadata {
    my (@data) = @_;

    %METADATA = @data;
}

END {
    if (not $CONFIG{'nodump'}) {
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

Version 0.100

=head1 SYNOPSIS

The following program sets up the coverage hook on C<use> and dumps a
report to the current working directory at the end of execution.

	use Devel::QuickCover;
        my $x = 1;
        my $z = 1 + $x;

The following program sets up the coverage hook on C<start()> and
dumps a report to the C<output_directory> on C<end()> at which
point the coverage hook gets uninstalled. So we only get coverage
information for C<bar()>.

       use Devel::QuickCover (nostart => 1, nodump => 1, output_directory => "some_dir/");
       foo();
       Devel::QuickCover::start();
       bar();
       Devel::QuickCover::add_metadata({ foo => "FOO", bar => "BAR" });
       Devel::QuickCover::end();
       baz();


=head1 DESCRIPTION

=head1 METHODS

=head1 AUTHORS

=over 4

=item * Gonzalo Diethelm C<< gonzus AT cpan DOT org >>

=back

=head1 THANKS

=over 4

=item * Mattia Barbon

=item * p5pclub

=back
