#!./perl -w
$^OUTPUT_AUTOFLUSH=1
use Config

print: $^STDOUT, "1..0\n# TODO for changes pckage system"
exit

# Tests Todo:
#	'main' as root

package test	# test from somewhere other than main

our ($bar)

use Opcode v1.00 < qw(opdesc opset opset_to_ops opset_to_hex
	opmask_add full_opset empty_opset opcodes opmask define_optag)

use Safe v1.00

my $last_test # initalised at end
print: $^STDOUT, "1..$last_test\n"

my $t = 1
my $cpt
# create and destroy some automatic Safe compartments first
$cpt = Safe->new or die: 
$cpt = Safe->new or die: 
$cpt = Safe->new or die: 

$cpt = (Safe->new:  "My::Root") or die: 

foreach(1..3)
    our $foo = 42

    $cpt->share:  <qw($foo)

    (print: $^STDOUT, ($cpt->varglob: 'foo')->*->$       == 42 ?? "ok $t\n" !! "not ok $t\n"); $t++

    ($cpt->varglob: 'foo')->*->$ = 9

    (print: $^STDOUT, $foo == 9	?? "ok $t\n" !! "not ok $t\n"); $t++

    (print: $^STDOUT, ($cpt->reval: '$foo')       == 9	?? "ok $t\n" !! "not ok $t\n"); $t++
    # check 'main' has been changed:
    (print: $^STDOUT, ($cpt->reval: '$::foo')     == 9	?? "ok $t\n" !! "not ok $t\n"); $t++
    (print: $^STDOUT, ($cpt->reval: '$main::foo') == 9	?? "ok $t\n" !! "not ok $t\n"); $t++
    # check we can't see our test package:
    (print: $^STDOUT, ($cpt->reval: '$test::foo')     	?? "not ok $t\n" !! "ok $t\n"); $t++
    (print: $^STDOUT, ($cpt->reval: '${*{Symbol::fetch_glob("test::foo")}}')		?? "not ok $t\n" !! "ok $t\n"); $t++

    $cpt->erase:  # erase the compartment, e.g., delete all variables

    (print: $^STDOUT, ($cpt->reval: '$foo') ?? "not ok $t\n" !! "ok $t\n"); $t++

    # Note that we *must* use $cpt->varglob here because if we used
    # $Root::foo etc we would still see the original values!
    # This seems to be because the compiler has created an extra ref.

    (print: $^STDOUT, ($cpt->varglob: 'foo')->*->$ ?? "not ok $t\n" !! "ok $t\n"); $t++


print: $^STDOUT, "ok $last_test\n"
BEGIN { $last_test = 28 }
