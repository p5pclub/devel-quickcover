
BEGIN { my $b = 0 } # YES
INIT  { my $c = 0 } # YES
CHECK { my $d = 0 } # YES
END   { my $e = 0 } # YES

sub used {
    my $a = 1;  # YES
    if (1) {    # YES
        $a = 2;
    }
    return $a;  # YES
}

sub unused {
    return 5;   # NO
}

used();         # YES
