use strict;
use warnings;
use File::Temp qw(tempdir);
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

done_testing;
