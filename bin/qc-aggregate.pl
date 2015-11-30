use strict;
use warnings;

use JSON        qw(encode_json   decode_json);
use Sereal      qw(encode_sereal decode_sereal);
use File::Slurp qw(read_file     write_file);
use Data::Dumper;

my $QC_DATABASE   = 'qc.dat';
my $QC_PATH       = '/tmp';
my $QC_PREFIXES   = 'QC';      # Could be '(QC|CQ|XX)'
my $QC_EXTENSIONS = 'txt';     # Could be '(txt|dat|db)'

exit main();

sub main {
    my $data = load_data($QC_DATABASE);
    printf("Initial data: %s\n", Dumper($data));

    my $changes = 0;
    my @files = get_file_list($QC_PATH);
    for my $file (@files) {
        process_file($file, $data, \$changes);
    }

    if (!$changes) {
        printf("Data unchanged, not saving\n");
    } else {
        printf("After %d changes, final data: %s\n", $changes, Dumper($data));
        save_data($QC_DATABASE, $data);
    }

    return 0;
}

sub load_data {
    my ($file) = @_;

    if (! -r $file) {
        if (-e $file) {
            printf("Can't read existing file [%s]\n", $file);
        } else {
            printf("Will create new file [%s]\n", $file);
        }
        return {};
    }

    my $data = read_file($file, { binmode => ':raw' });
    if (!$data) {
        printf("Got no data from file [%s]\n", $file);
        return {};
    }

    my $decoded = Sereal::decode_sereal($data);
    if (!$decoded) {
        printf("Could not Sereal-decode data for file [%s]\n", $file);
        return {};
    }

    return $decoded;
}

sub save_data {
    my ($file, $data) = @_;

    if (!$data) {
        printf("Will not write null data to file [%s]\n", $file);
        return;
    }

    my $encoded = Sereal::encode_sereal($data);
    if (!$encoded) {
        printf("Could not Sereal-encode data for file [%s]\n", $file);
        return;
    }

    if (!write_file($file, { binmode => ':raw' }, $encoded)) {
        printf("Can't write file [%s]\n", $file);
        return;
    }
}

sub get_file_list {
    my ($path) = @_;

    if (!opendir(DIR, $path)) {
        printf("Could not read directory [%s]\n", $path);
        return ();
    }

    my @list;
    while (my $file = readdir(DIR)) {
        # Ignore files beginning with a period
        next if ($file =~ m/^\./);

        # Ignore files that don't match QC_*.txt
        next if ($file !~ m/^($QC_PREFIXES)_.*\.($QC_EXTENSIONS)$/);

        push(@list, $path . '/' . $file);
    }
    closedir(DIR);
    return @list;
}

sub process_file {
    my ($file, $data, $changes) = @_;

    printf("Processing file %s... ", $file);
    my $json = read_file($file);
    if (!$json) {
        printf("Got no JSON data from file [%s]\n", $file);
        return;
    }

    my $decoded = JSON::decode_json($json);
    if (!$decoded) {
        printf("Could not JSON-decode data for file [%s]\n", $file);
        return;
    }

    for my $name (keys %{$decoded->{files}}) {
        my $lines = $decoded->{files}{$name};
        for my $line (@$lines) {
            for my $number (keys %$line) {
                $data->{$name}->{$number} += $line->{$number};
                ++$$changes;
            }
        }
    }

    unlink($file);
    printf("Done\n");
}
