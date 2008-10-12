#!./perl -w
#
# Contributed by Graham Barr <Graham.Barr@tiuk.ti.com>

our $warn;
BEGIN {
    $warn = "";
    $^WARN_HOOK = sub { $warn .= @_[0]->message }
}

sub ok ($$) { 
    print @_[1] ? "ok " : "not ok ", @_[0], "\n";
}

print "1..1\n";

my $NEWPROTO = 'Prototype mismatch:';

sub sub0 { 1 }
sub sub0 { 2 }

ok 1, $warn =~ s/Subroutine sub0 redefined[^\n]+\n//s;
