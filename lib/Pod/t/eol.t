#!./perl -w

use Test::More tests => 3;

open(POD, ">", "$^PID.pod") or die "$^PID.pod: $^OS_ERROR";
print POD <<__EOF__;
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
close(POD);

use Pod::Html;

# --- CR ---

open(POD, "<", "$^PID.pod") or die "$^PID.pod: $^OS_ERROR";
open(IN, ">",  "$^PID.in")  or die "$^PID.in: $^OS_ERROR";
while ( ~< *POD) {
  s/[\r\n]+/\r/g;
  print IN $_;
}
close(POD);
close(IN);

pod2html("--title=eol", "--infile=$^PID.in", "--outfile=$^PID.o1");

# --- LF ---

open(POD, "<", "$^PID.pod") or die "$^PID.pod: $^OS_ERROR";
open(IN, ">",  "$^PID.in")  or die "$^PID.in: $^OS_ERROR";
while ( ~< *POD) {
  s/[\r\n]+/\n/g;
  print IN $_;
}
close(POD);
close(IN);

pod2html("--title=eol", "--infile=$^PID.in", "--outfile=$^PID.o2");

# --- CRLF ---

open(POD, "<", "$^PID.pod") or die "$^PID.pod: $^OS_ERROR";
open(IN, ">",  "$^PID.in")  or die "$^PID.in: $^OS_ERROR";
while ( ~< *POD) {
  s/[\r\n]+/\r\n/g;
  print IN $_;
}
close(POD);
close(IN);

pod2html("--title=eol", "--infile=$^PID.in", "--outfile=$^PID.o3");

# --- now test ---

local $^INPUT_RECORD_SEPARATOR;

open(IN, "<", "$^PID.o1") or die "$^PID.o1: $^OS_ERROR";
my $cksum1 = unpack("\%32C*", ~< *IN);

open(IN, "<", "$^PID.o2") or die "$^PID.o2: $^OS_ERROR";
my $cksum2 = unpack("\%32C*", ~< *IN);

open(IN, "<", "$^PID.o3") or die "$^PID.o3: $^OS_ERROR";
my $cksum3 = unpack("\%32C*", ~< *IN);

ok($cksum1 == $cksum2, "CR vs LF");
ok($cksum1 == $cksum3, "CR vs CRLF");
ok($cksum2 == $cksum3, "LF vs CRLF");
close IN;

END {
  1 while unlink("$^PID.pod", "$^PID.in", "$^PID.o1", "$^PID.o2", "$^PID.o3",
                 "pod2htmd.x~~", "pod2htmi.x~~");
}
