use strict;
use warnings;

use JSON        qw(encode_json   decode_json);
use Sereal      qw(encode_sereal decode_sereal);
use File::Slurp qw(read_file     write_file);
use File::Temp  qw(tempdir);
use Test::More;

BEGIN {
    my $dir = tempdir( "quickcover-test-XXXX", TMPDIR => 1);
    require Devel::QuickCover;
    Devel::QuickCover->import(nostart=>1, nodump=>1, output_directory=>$dir);
}

my $x=1;
Devel::QuickCover::start();
my $y=2;
Devel::QuickCover::end();
my $z=3;

my @files = glob($Devel::QuickCover::CONFIG{output_directory}."/*");
ok(@files == 1, "Report exists at $Devel::QuickCover::CONFIG{output_directory}");

if (@files == 1) {
    ok(report_only_for_lines($files[0], 18,19), "Report only contains the half-open interval ]start(), end()]");
}
done_testing;


sub report_only_for_lines {
    my ($fname, @lines) = @_;

    my %l;


    my $json = read_file($fname);
    if (!$json) {
        return;
    }

    my $decoded = JSON::decode_json($json);
    if (!$decoded) {
        return;
    }

    for my $name (keys %{$decoded->{files}}) {
        my $lines = $decoded->{files}{$name};
        for my $line (@$lines) {
            for my $number (keys %$line) {
                $l{$number} = 1;
            }
        }
    }

    foreach (@lines) {
        return if not delete $l{$_};
    }
    return not keys %l;
}
