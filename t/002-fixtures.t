
use strict;
use warnings;

use lib './t/lib';
use Test::QuickCover qw (read_report get_coverage_from_report parse_fixture);

use File::Temp  qw(tempdir);
use Test::More;

my $FIXTURES = './fixtures';
my $dir      = tempdir( "quickcover-test-XXXX", TMPDIR => 1);

sub test_fixture {
    my $file = shift;
    my @cmd = (
        'perl',
        '-I./blib/lib',
        '-I./blib/arch/',
        "-MDevel::QuickCover=output_directory,$dir",
        $file,
    );
    system( @cmd );

    my ($report_fname, $report) = read_report( $dir )
        or fail "Got report after execution for $file";

    my $got      = get_coverage_from_report( $file, $report );
    my $expected = parse_fixture( $file );

    is_deeply( $got, $expected, "Got what we expected from the report for $file" );

    $report_fname
        and unlink $report_fname;
}

for my $file (glob "$FIXTURES/*.pl") {
    test_fixture($file);
}

done_testing;
