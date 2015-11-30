
sub used {
    my $a = 1;  # YES
    if (1) {    # YES
        $a = 2;
    }
    return $a;  # YES
}

sub unused {
    return 5;
}

used();         # YES
