#!/usr/bin/env perl

use strict;
use warnings;

# Generate a Devel::Cover-compatible report file from cover data.

use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use File::Slurp qw(read_file write_file);
use Getopt::Long;
use JSON::XS;
use Sereal qw(encode_sereal decode_sereal);

my $QC_DATABASE   = 'qc.dat';
my $COVERDB       = './cover_db/';
my %PATH_REWRITES = ();

GetOptions('input=s'         => \$QC_DATABASE,
           'cover-db=s'      => \$COVERDB,
           'path-rewrite=s%' => \%PATH_REWRITES,
);

my $DIGESTS       = "$COVERDB/digests";
my $STRUCTURE     = "$COVERDB/structure/";
my $RUNS          = "$COVERDB/runs/";

my $JSON          = JSON::XS->new->utf8;
my $DEVEL_COVER_DB_FORMAT = 'Sereal';
$ENV{DEVEL_COVER_DB_FORMAT}
    and $DEVEL_COVER_DB_FORMAT = 'JSON';

exit main();

sub main {
    my $data = load_data($QC_DATABASE);

    make_coverdb_directories();
    generate_cover_db($data);

    return 0;
}

sub make_coverdb_directories {
    -d $COVERDB
        or mkdir $COVERDB;

    -d $STRUCTURE
        or mkdir $STRUCTURE;

    -d $RUNS
        or mkdir $RUNS;
}

sub load_data {
    my $file = shift;

    my $data = read_file($file, { binmode => ':raw' })
        or die "Can't read the data";

    my $decoded = Sereal::decode_sereal($data)
        or die "Can't decode the input data";

    return $decoded;
}

sub coverdb_decode {
    if ($DEVEL_COVER_DB_FORMAT eq 'JSON') {
       return $JSON->decode(shift);
    }
    return decode_sereal(shift);
}

sub coverdb_encode {
    if ($DEVEL_COVER_DB_FORMAT eq 'JSON') {
        return $JSON->encode(shift);
    }
    return encode_sereal(shift);
}

sub generate_cover_db {
    my $data     = shift;
    my $digests  = {};

    if (-r $DIGESTS) {
        my $digests_data = read_file($DIGESTS, { binmode => ':raw' });
        $digests //= coverdb_decode( $digests_data );
    }

    my $run = {
        OS        => 'xx',
        collected => [ 'statement' ],
        count     => {},
        digests   => {},
        start     => 0,
        run       => 'xx',
    };

    for my $file (keys %{ $data }) {
        while ( my ($from, $to) = each %PATH_REWRITES ) {
            $file =~ s/$from/$to/;
        }
        if (!-r $file) {
            print "Skipping $file for now. Probably an eval\n";
            next;
        }

        my $hits              = $data->{ $file };
        my ($statement, $md5) = process_file_structure($file, $digests);

        $run->{count}{$file}{statement} = [ map +( $hits->{ $_ } // 0), @{ $statement } ];
        $run->{digests}{$file}          = $md5;
    }

    write_file( $DIGESTS, { binmode => ':raw' }, coverdb_encode( $digests ) );

    my $run_id = rand(1000);
    my $run_structure = { runs => { $run_id => $run } };
    mkdir ( "$RUNS/$run_id" );

    write_file ( "$RUNS/$run_id/cover.14", { binmode => ':raw' }, coverdb_encode( $run_structure ) );
}

sub process_file_structure {
    my ($file, $digests) = @_;

    my $content = read_file($file, { binmode => ':raw'});
    my $md5     = md5_hex( $content );
    my $statement;

    if (! exists($digests->{ $md5 })) {
        $digests->{ $md5 } = $file;
        $statement         = write_structure($file, $md5, $content);
    } else {
        my $structure_data = read_file( "$STRUCTURE/$md5", { binmode => ':raw' });
        my $structure      = coverdb_decode($structure_data);
        $statement         = $structure->{statement};
    }
    return $statement, $md5;
}

sub write_structure {
    my ($file, $md5, $content) = @_;

    my @lines   = split /\n/, $content;
    my $statement = [
        map  $_->[0],                                   # get the line number
        grep $_->[1] !~ /^\s*#/ && $_->[1] !~ /^\s*$/,  # ignore comments and whitespaces
        map  [ $_ + 1, $lines[$_] ], 0 .. $#lines,      # enumerate($data)
    ];

    my $structure = {
        file       => $file,
        digest     => $md5,
        start      => {},
        statement  => $statement,
        subroutine => [],
    };

    write_file( "$STRUCTURE/$md5", { binmode => ':raw' }, coverdb_encode( $structure ));
    return $statement;
}
