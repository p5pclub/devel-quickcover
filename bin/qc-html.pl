#!/usr/bin/perl

use strict;
use warnings;

use Sereal qw(encode_sereal decode_sereal);
use File::Slurp qw(read_file);

my $QC_DATABASE   = 'qc.dat';

sub main() {
    my $data = load_data($QC_DATABASE);

    generate_html($data);

    return 0;
}

sub load_data {
    my $file = shift;

    my $data = read_file($file, { binmode => ':raw' })
        or die "Can't read the data";

    my $decoded = Sereal::decode_sereal($data)
        or die "Can't decode the input data";

    return $decoded;
}

sub generate_html {
    my $data = shift;

    for my $file (keys %{ $data }) {
        my @lines = keys $data->{$file};
        my $cmd   = "pygmentize -f html -O full,linenos=inline,stripnl=0,hl_lines='@lines' -o $file.html $file";

        exec($cmd)
            or print STDERR "Error calling pygmentize: $!";
    }
}

exit main();
