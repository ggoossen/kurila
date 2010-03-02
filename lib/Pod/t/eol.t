#!./perl -w

use Test::More tests => 3

open: my $pod, ">", "$^PID.pod" or die: "$^PID.pod: $^OS_ERROR"
print: $pod ,<<__EOF__
=pod

=head1 NAME

crlf

=head1 DESCRIPTION

crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf
crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf
crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf
crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf

    crlf crlf crlf crlf
    crlf crlf crlf crlf
    crlf crlf crlf crlf

crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf
crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf
crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf
crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf crlf

=cut
__EOF__
close: $pod

use Pod::Html

# --- CR ---

my $in
open: $pod, "<", "$^PID.pod" or die: "$^PID.pod: $^OS_ERROR"
open: $in, ">",  "$^PID.in"  or die: "$^PID.in: $^OS_ERROR"
while ( ~< $pod)
    s/[\r\n]+/\r/g
    print: $in, $_

close: $pod
close: $in

pod2html: "--title=eol", "--infile=$^PID.in", "--outfile=$^PID.o1"

# --- LF ---

open: $pod, "<", "$^PID.pod" or die: "$^PID.pod: $^OS_ERROR"
open: $in, ">",  "$^PID.in"  or die: "$^PID.in: $^OS_ERROR"
while ( ~< $pod)
    s/[\r\n]+/\n/g
    print: $in, $_

close: $pod
close: $in

pod2html: "--title=eol", "--infile=$^PID.in", "--outfile=$^PID.o2"

# --- CRLF ---

open: $pod, "<", "$^PID.pod" or die: "$^PID.pod: $^OS_ERROR"
open: $in, ">",  "$^PID.in"  or die: "$^PID.in: $^OS_ERROR"
while ( ~< $pod)
    s/[\r\n]+/\r\n/g
    print: $in, $_

close: $pod
close: $in

pod2html: "--title=eol", "--infile=$^PID.in", "--outfile=$^PID.o3"

# --- now test ---

local $^INPUT_RECORD_SEPARATOR = undef

open: $in, "<", "$^PID.o1" or die: "$^PID.o1: $^OS_ERROR"
my $cksum1 = unpack: "\%32C*", ~< $in

open: $in, "<", "$^PID.o2" or die: "$^PID.o2: $^OS_ERROR"
my $cksum2 = unpack: "\%32C*", ~< $in

open: $in, "<", "$^PID.o3" or die: "$^PID.o3: $^OS_ERROR"
my $cksum3 = unpack: "\%32C*", ~< $in

ok: $cksum1 == $cksum2, "CR vs LF"
ok: $cksum1 == $cksum3, "CR vs CRLF"
ok: $cksum2 == $cksum3, "LF vs CRLF"
close $in

END 
    1 while unlink: "$^PID.pod", "$^PID.in", "$^PID.o1", "$^PID.o2", "$^PID.o3"
                    "pod2htmd.x~~", "pod2htmi.x~~"

