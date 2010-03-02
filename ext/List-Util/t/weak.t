#!./perl

use Config

use Scalar::Util ()
use Test::More  ((grep: { m/weaken/ }, @Scalar::Util::EXPORT_FAIL))
    ?? (skip_all => 'weaken requires XS version')
    !! (tests => 22)

if (0)
    require Devel::Peek
    Devel::Peek->import: 'Dump'
else
    *Dump = sub {}


Scalar::Util->import:  < qw(weaken isweak)

if(1)

    my ($y,$z)

    #
    # Case 1: two references, one is weakened, the other is then undef'ed.
    #

    do
        my $x = "foo"
        $y = \$x
        $z = \$x
    
    print: $^STDOUT, "# START\n"(
    Dump: $y); Dump: $z

    ok:  ref: $y and ref: $z

    print: $^STDOUT, "# WEAK:\n"
    weaken: $y(
    Dump: $y); Dump: $z

    ok:  ref: $y and ref: $z

    print: $^STDOUT, "# UNDZ:\n"
    undef($z)(
    Dump: $y); Dump: $z

    ok:  (not: defined: $y and defined: $z) 

    print: $^STDOUT, "# UNDY:\n"
    undef($y)(
    Dump: $y); Dump: $z

    ok:  (not: defined: $y and defined: $z) 

    print: $^STDOUT, "# FIN:\n"(
    Dump: $y); Dump: $z


    #
    # Case 2: one reference, which is weakened
    #

    print: $^STDOUT, "# CASE 2:\n"

    do
        my $x = "foo"
        $y = \$x
    

    ok:  (ref: $y) 
    print: $^STDOUT, "# BW: \n"
    Dump: $y
    weaken: $y
    print: $^STDOUT, "# AW: \n"
    Dump: $y
    ok:  not defined $y  

    print: $^STDOUT, "# EXITBLOCK\n"


#
# Case 3: a circular structure
#

my $flag = 0
do
    my $y = bless: \$%, 'Dest'
    Dump: $y
    $y->{+Self} = $y
    Dump: $y
    $y->{+Flag} = \$flag
    weaken: $y->{?Self}
    print: $^STDOUT, "# WKED\n"
    ok:  (ref: $y) 
    print: $^STDOUT, "# VALS: HASH ", (dump::view: $y),"   SELF ", (dump::view: \$y->{+Self}),"  Y ", (dump::view: \$y)
           "    FLAG: ", (dump::view: \$y->{+Flag}),"\n"
    print: $^STDOUT, "# VPRINT\n"

print: $^STDOUT, "# OUT $flag\n"
ok:  $flag == 1 

print: $^STDOUT, "# AFTER\n"

undef $flag

print: $^STDOUT, "# FLAGU\n"

#
# Case 4: a more complicated circular structure
#

$flag = 0
do
    my $y = bless: \$%, 'Dest'
    my $x = bless: \$%, 'Dest'
    $x->{+Ref} = $y
    $y->{+Ref} = $x
    $x->{+Flag} = \$flag
    $y->{+Flag} = \$flag
    weaken: $x->{?Ref}

ok:  $flag == 2 

#
# Case 5: deleting a weakref before the other one
#

our ($y, $z)
do
    my $x = "foo"
    $y = \$x
    $z = \$x


print: $^STDOUT, "# CASE5\n"
Dump: $y

weaken: $y
Dump: $y
undef($y)

ok:  not defined $y
ok:  (ref: $z) 


#
# Case 6: test isweakref
#

$a = 5
ok: !(isweak: $a)
$b = \$a
ok: !(isweak: $b)
weaken: $b
ok: (isweak: $b)
$b = \$a
ok: !(isweak: $b)

our $x = \$%
weaken: ($x->{+Y} = \$a)
ok: (isweak: $x->{?Y})
ok: !(isweak: $x->{?Z})

#
# Case 7: test weaken on a read only ref
#

:SKIP do
    # in a MAD build, constants have refcnt 2, not 1
    skip: "Test does not work with MAD", 5 if config_value: "mad"

    $a = eval '\"hello"'
    ok: (ref: $a) or print: $^STDOUT, "# didn't get a ref from eval\n"
    $b = $a
    try{(weaken: $b)}
    # we didn't die
    ok: $^EVAL_ERROR eq "" or print: $^STDOUT, "# died with $^EVAL_ERROR\n"
    ok: (isweak: $b)
    ok: $b->$ eq "hello" or print: $^STDOUT, "# b is '$b->$'\n"
    $a=""
    ok: not $b or print: $^STDOUT, "# b didn't go away\n"


package Dest

sub DESTROY
    print: $^STDOUT, "# INCFLAG\n"
    @_[0]->{Flag}->$ ++

