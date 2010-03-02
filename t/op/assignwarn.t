#!./perl

#
# Verify which OP= operators warn if their targets are undefined.
# Based on redef.t, contributed by Graham Barr <Graham.Barr@tiuk.ti.com>
#	-- Robin Barker <rmb@cise.npl.co.uk>
#

BEGIN 
    require './test.pl'


use warnings

my $warn = ""
$^WARN_HOOK = sub (@< @_) { (print: $^STDOUT, $warn); $warn .= @_[0]->{?description} . "\n" }

sub uninitialized { $warn =~ s/Use of uninitialized value[^\n]+\n//s; }
sub tiex { }
our $TODO

print: $^STDOUT, "1..32\n"

# go through all tests once normally and once with tied $x
for my $tie ((@: ""))

    do { my $x; tiex: $x if $tie; $x ++;     ok: ! (uninitialized: ), "postinc$tie"; }
    do { my $x; tiex: $x if $tie; $x --;     ok: ! (uninitialized: ), "postdec$tie"; }
    do { my $x; tiex: $x if $tie; ++ $x;     ok: ! (uninitialized: ), "preinc$tie"; }
    do { my $x; tiex: $x if $tie; -- $x;     ok: ! (uninitialized: ), "predec$tie"; }

    do { my $x; tiex: $x if $tie; $x **= 1;  ok: (uninitialized: ),   "**=$tie"; }

    do { local $TODO = $tie && '[perl #17809] pp_add & pp_subtract';
        do { my $x; tiex: $x if $tie; $x += 1;   ok: ! (uninitialized: ), "+=$tie"; };
        do { my $x; tiex: $x if $tie; $x -= 1;   ok: ! (uninitialized: ), "-=$tie"; };
    }

    do { my $x; tiex: $x if $tie; $x .= 1;   ok: ! (uninitialized: ), ".=$tie"; }

    do { my $x; tiex: $x if $tie; $x *= 1;   ok: (uninitialized: ),   "*=$tie"; }
    do { my $x; tiex: $x if $tie; $x /= 1;   ok: (uninitialized: ),   "/=$tie"; }
    do { my $x; tiex: $x if $tie; $x %= 1;   ok: (uninitialized: ),   "\%=$tie"; }

    do { my $x; tiex: $x if $tie; $x x= 1;   ok: (uninitialized: ), "x=$tie"; }

    do { my $x; tiex: $x if $tie; $x ^&^= 1;   ok: (uninitialized: ), "&=$tie"; }

    do { local $TODO = $tie && '[perl #17809] pp_bit_or & pp_bit_xor';
        do { my $x; tiex: $x if $tie; $x ^|^= 1;   ok: ! (uninitialized: ), "|=$tie"; };
        do { my $x; tiex: $x if $tie; $x ^^^= 1;   ok: ! (uninitialized: ), "^=$tie"; };
    }

    do { my $x; tiex: $x if $tie; $x &&= 1;  ok: ! (uninitialized: ), "&&=$tie"; }
    do { my $x; tiex: $x if $tie; $x ||= 1;  ok: ! (uninitialized: ), "||=$tie"; }

    do { my $x; tiex: $x if $tie; $x <<= 1;  ok: (uninitialized: ), "<<=$tie"; }
    do { my $x; tiex: $x if $tie; $x >>= 1;  ok: (uninitialized: ), ">>=$tie"; }

    do { my $x; tiex: $x if $tie; $x ^&^= "x"; ok: (uninitialized: ), "&=$tie, string"; }

    do { local $TODO = $tie && '[perl #17809] pp_bit_or & pp_bit_xor';
        do { my $x; tiex: $x if $tie; $x ^|^= "x"; ok: ! (uninitialized: ), "|=$tie, string"; };
        do { my $x; tiex: $x if $tie; $x ^^^= "x"; ok: ! (uninitialized: ), "^=$tie, string"; };
    }

    do { use integer;

        do { local $TODO = $tie && '[perl #17809] pp_i_add & pp_i_subtract';
            do { my $x; tiex: $x if $tie; $x += 1; ok: ! (uninitialized: ), "+=$tie, int"; };
            do { my $x; tiex: $x if $tie; $x -= 1; ok: ! (uninitialized: ), "-=$tie, int"; };
        };

        do { my $x; tiex: $x if $tie; $x *= 1; ok: (uninitialized: ), "*=$tie, int"; };
        do { my $x; tiex: $x if $tie; $x /= 1; ok: (uninitialized: ), "/=$tie, int"; };
        do { my $x; tiex: $x if $tie; $x %= 1; ok: (uninitialized: ), "\%=$tie, int"; };

        do { my $x; tiex: $x if $tie; $x ++;   ok: ! (uninitialized: ), "postinc$tie, int"; };
        do { my $x; tiex: $x if $tie; $x --;   ok: ! (uninitialized: ), "postdec$tie, int"; };
        do { my $x; tiex: $x if $tie; ++ $x;   ok: ! (uninitialized: ), "preinc$tie, int"; };
        do { my $x; tiex: $x if $tie; -- $x;   ok: ! (uninitialized: ), "predec$tie, int"; };

    } # end of use integer;

 # end of for $tie

is: $warn, '', "no spurious warnings"
