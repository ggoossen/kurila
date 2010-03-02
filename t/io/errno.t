#!./perl
# vim: ts=4 sts=4 sw=4:

# $! may not be set if EOF was reached without any error.
# http://rt.perl.org/rt3/Ticket/Display.html?id=39060

require './test.pl'

plan:  tests => 16 

my $test_prog = 'while(~< *ARGV){print $^STDOUT, $_}; print $^STDOUT, $^OS_ERROR'

for my $perlio (@: 'perlio', 'stdio')
    (env::var: 'PERLIO') = $perlio
    for my $test_in (@: "test\n", "test")
        my $test_in_esc = $test_in
        $test_in_esc =~ s/\n/\\n/g
        for my $rs_code (@: '', '$^INPUT_RECORD_SEPARATOR=undef', '$^INPUT_RECORD_SEPARATOR=\2', '$^INPUT_RECORD_SEPARATOR=\1024')
            is:  (runperl:  prog => "$rs_code; $test_prog"
                            stdin => $test_in, stderr => 1)
                 $test_in
                 "Wrong errno, PERLIO=$((env::var: 'PERLIO')) stdin='$test_in_esc'"
