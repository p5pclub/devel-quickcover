package t::lib::Test;

use parent 'Test::Builder::Module';

use Test::More;
use JSON::XS    qw( decode_json );
use File::Slurp qw( read_file );

our @EXPORT= (
     @Test::More::EXPORT,
     qw(
        read_report
        get_coverage_from_report
        parse_fixture
     )
);

sub import {
    unshift @INC, 't/lib';

    strict->import;
    warnings->import;

    goto &Test::Builder::Module::import;
}

sub read_report {
    my $path  = shift // '/tmp';
    my @files = glob("$path/QC_*");

    ok(@files == 1, "Report exists at $path")
        or return;

    my ($fname) =  @files;

    my $json = read_file($fname)
        or return;

    my $decoded = decode_json($json)
        or return;

    return $fname, $decoded;
}

sub get_coverage_from_report {
    my ($file, $report) = @_;

    my $lines = $report->{files}{$file};

    return $lines
}

sub parse_fixture {
    my $file = shift;

    my $content = read_file($file);
    my @lines = split /\n/, $content;

    use Data::Dumper;

    my %expected =
        map  +($_->[0], 1),                      # pairs (lineno, 1)
        grep +($_->[1] =~ /YES/),                # look for lines marked with YES
        map  [ $_ + 1, $lines[$_] ], 0..$#lines; # enumerate

    return \%expected;
}


1;
