
sub used {
    my $a = 1;
    if (1) {
        $a = 2;
    }
    return $a;
}

sub unused {
    return 5;
}

used();
