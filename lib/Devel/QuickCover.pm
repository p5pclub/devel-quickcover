package Devel::QuickCover;
use strict;
use warnings;
use XSLoader;

our $VERSION = '0.11';

XSLoader::load( 'Devel::QuickCover', $VERSION );

sub import {
    Devel::QuickCover::start();
}

END {
    Devel::QuickCover::dump();
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

Devel::QuickCover - Quick & dirty code coverage for Perl

=head1 VERSION

Version 0.100

=head1 NAME

=head1 SYNOPSIS

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
