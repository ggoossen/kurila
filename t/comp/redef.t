#!./perl -w
#
# Contributed by Graham Barr <Graham.Barr@tiuk.ti.com>

our $warn
BEGIN 
    $warn = ""
    $^WARN_HOOK = sub (@< @_) { $warn .= @_[0]->message }


sub ok($nr, $ok)
    print: $^STDOUT, $ok ?? "ok " !! "not ok ", $nr, "\n"


print: $^STDOUT, "1..1\n"

my $NEWPROTO = 'Prototype mismatch:'

sub sub0 { 1 }
sub sub0 { 2 }

ok: 1, $warn =~ s/Subroutine sub0 redefined//s
