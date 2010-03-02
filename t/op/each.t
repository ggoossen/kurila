#!./perl

BEGIN 
    require './test.pl'


plan: tests => 27

our (%h, @keys, @values, $i, $key, $value, $size, $newsize, $total,
    %hash, @foo, %u, $A, %b)

%h{+'abc'} = 'ABC'
%h{+'def'} = 'DEF'
%h{+'a'} = 'A'
%h{+'b'} = 'B'
%h{+'c'} = 'C'
%h{+'d'} = 'D'
%h{+'e'} = 'E'
%h{+'f'} = 'F'
%h{+'g'} = 'G'
%h{+'h'} = 'H'
%h{+'i'} = 'I'
%h{+'j'} = 'J'
%h{+'k'} = 'K'
%h{+'l'} = 'L'
%h{+'m'} = 'M'
%h{+'n'} = 'N'
%h{+'o'} = 'O'
%h{+'p'} = 'P'
%h{+'q'} = 'Q'
%h{+'r'} = 'R'
%h{+'s'} = 'S'
%h{+'t'} = 'T'
%h{+'u'} = 'U'
%h{+'v'} = 'V'
%h{+'w'} = 'W'
%h{+'x'} = 'X'
%h{+'y'} = 'Y'
%h{+'z'} = 'Z'

@keys = keys %h
@values = values %h

is: ((nelems @keys)-1), 27, "keys"
is: ((nelems @values)-1), 27, "values"

$i = 0		# stop -w complaints

while ((@: ?$key,?$value) = @: (each: %h))
    if ($key eq @keys[$i] && $value eq @values[$i]
          && (($key cmp $value) +> 0))
        $key =~ s/([a-z])/$((uc: $1))/g
        $i++ if $key eq $value
    


is: $i, 28, "each count"

@keys = @: 'blurfl', < (keys: %h), 'dyick'
is: ((nelems @keys)-1), 29, "added a key"

# test scalar each
%hash = %:  < 1..20 
$total = 0
$total += $key while $key = each %hash
is: $total, 100, "test scalar each"

for (1..3) { @foo = (@:  each %hash ) }
keys %hash
$total = 0
$total += $key while $key = each %hash
is: $total, 100, "test scalar keys resets iterator"

for (1..3) { @foo = (@:  each %hash ) }
$total = 0
$total += $key while $key = each %hash
isnt: $total, 100, "test iterator of each is being maintained"

for (1..3) { @foo = (@:  each %hash ) }
values %hash
$total = 0
$total += $key while $key = each %hash
is: $total, 100, "test values keys resets iterator"

$i = 0
%h = %: a => 'A', b => 'B', c=> 'C', d => 'D', abc => 'ABC'
@keys = keys: %h
@values = values: %h
while ((@: ?$key, ?$value) = @: (each: %h))
    if ($key eq @keys[$i] && $value eq @values[$i] && $key eq (lc: $value))
        $i++
    

is: $i, 5

our @tests = @: (next_test:  < @_ ), (next_test:  < @_ ), next_test:  < @_ 
do
    package Obj
    sub DESTROY { (print: $^STDOUT, "ok @::tests[?1] # DESTROY called\n"); }
    do
        my $h = \%:  A => bless: \$@, __PACKAGE__ 
        while (my(@: ?$k,?$v) =(@:  each $h->%))
            print: $^STDOUT, "ok @::tests[?0]\n" if $k eq 'A' and (ref: $v) eq 'Obj'
        
    
    print: $^STDOUT, "ok @::tests[?2]\n"


# Check for Unicode hash keys.
use utf8
%u = %: "\x{12}", "f", "\x{123}", "fo", "\x{1234}",  "foo"
%u{+"\x{12345}"}  = "bar"
%u{[(@: "\x{10FFFD}")]} = @: "zap"

my %u2
foreach (keys %u)
    is: (length: ), 1, "Check length of " . (_qq: $_)
    %u2{+$_} = %u{?$_}

ok: (eq_hash: \%u, \%u2), "copied unicode hash keys correctly?"

$a = "\x[e3]\x[81]\x[82]"; $A = "\x{3042}"
%b = %:  $a => "non-utf8"
%u = %:  $A => "utf8"

is: exists %b{$A}, '1', "hash uses byte-string"
is: exists %u{$a}, '1', "hash uses byte-string"
for (keys %b)
    print: $^STDOUT, "# %b{?$_}\n"  # Used to core dump before change #8056.
pass: "if we got here change 8056 worked"
for (keys %u)
    print: $^STDOUT, "# %u{?$_}\n" # Used to core dump before change #8056.
pass: "change 8056 is thanks to Inaba Hiroto"

do
    my %u
    my $u0 = pack: "U0U", 0x00FF
    my $b0 = "\x[C3]\x[BF]"          # 0xCB 0xBF is U+00FF in UTF-8
    my $u1 = pack: "U0U", 0x0100
    my $b1 = "\x[C4]\x[80]"          # 0xC4 0x80 is U+0100 in UTF-8

    %u{+$u0} = 1
    %u{+$b0} = 2
    %u{+$u1} = 3
    %u{+$b1} = 4

    is: nkeys %u, 2, "two different keys (byte and unicode are the same)"
    is: %u{?$u0}, 2, "U+00FF=\\xC3\\xBF  -> 2"
    is: %u{?$b0}, 2, "\\xC3\\xBF=U+00FF  -> 2"
    is: %u{?$u1}, 4, "U+0100=\\xC4\\x80  -> 4 "
    is: %u{?$b1}, 4, "\\xC4\\x80=U+0100  -> 4"

