#!./perl -w
$^OUTPUT_AUTOFLUSH=1
use Config

print: $^STDOUT, "1..0\n# TODO for changes pckage system"
exit

# Tests Todo:
#	'main' as root

our ($bar)

use Opcode v1.00 < qw(opdesc opset opset_to_ops opset_to_hex
	opmask_add full_opset empty_opset opcodes opmask define_optag)

use Safe v1.00

my $last_test # initalised at end
print: $^STDOUT, "1..$last_test\n"

# Set up a package namespace of things to be visible to the unsafe code
$My::Root::main::foo = "visible"
$bar = "invisible"

# Stop perl from moaning about identifies which are apparently only used once
$My::Root::main::foo .= ""

my $cpt
# create and destroy a couple of automatic Safe compartments first
$cpt = Safe->new or die: 
$cpt = Safe->new or die: 

$cpt = Safe->new:  "My::Root"

$cpt->permit:  <qw(:base_io)

$cpt->reval: q{ system("echo not ok 1"); }
if ($^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/^'?system'? trapped by operation mask/)
    print: $^STDOUT, "ok 1\n"
else
    print: $^STDOUT, "#$^EVAL_ERROR" if $^EVAL_ERROR
    print: $^STDOUT, "not ok 1\n"


$cpt->reval: q{
    our ($foo, $bar);
    print $foo eq 'visible'		? "ok 2\n" : "not ok 2\n";
    print $main::foo  eq 'visible'	? "ok 3\n" : "not ok 3\n";
    print defined($bar)			? "not ok 4\n" : "ok 4\n";
    print defined($main::bar)		? "not ok 5\n" : "ok 5\n";
    print defined($main::bar)		? "not ok 6\n" : "ok 6\n";
}
print: $^STDOUT, $^EVAL_ERROR ?? "not ok 7\n#$($^EVAL_ERROR->message)" !! "ok 7\n"

our $foo = "ok 8\n"
our %bar = %: key => "ok 9\n"
our @baz = $@; push: @baz, "o", "10"
our @glob = qw(not ok 16)

sub sayok { (print: $^STDOUT, "ok $((join: ' ',@_))\n") }

$cpt->share:  <qw($foo %bar @baz sayok)

$cpt->reval: q{
    package other;
    sub other_sayok { print "ok @_[0]\n" }
    package main;
    our ($foo, %bar, @baz, @glob);
    print $foo ? $foo : "not ok 8\n";
    print %bar{key} ? %bar{key} : "not ok 9\n";
    (@baz) ? print "@baz[0]\n" : print "not ok 10\n";
    print "ok 11\n";
    other::other_sayok(12);
    $foo =~ s/8/14/;
    %bar{new} = "ok 15\n";
    @glob = @(qw(ok 16));
}
print: $^STDOUT, $^EVAL_ERROR ?? "not ok 13\n#$($^EVAL_ERROR->message)" !! "ok 13\n"
print: $^STDOUT, $foo, %bar{?new}, "$((join: ' ',@glob))\n"

$Root::foo = "not ok 17"
($cpt->varglob: 'bar')->@ = qw(not ok 18)
($cpt->varglob: 'foo')->$ = "ok 17"
@Root::bar = @:  "ok" 
push: @Root::bar, "18" # Two steps to prevent "Identifier used only once..."

print: $^STDOUT, "$Root::foo\n"
print: $^STDOUT, (join: ' ',($cpt->varglob: 'bar')->@) . "\n"


print: $^STDOUT, 1 ?? "ok 19\n" !! "not ok 19\n"
print: $^STDOUT, 1 ?? "ok 20\n" !! "not ok 20\n"

my $m1 = $cpt->mask
$cpt->trap: "negate"
my $m2 = $cpt->mask
my @masked = opset_to_ops: $m1
print: $^STDOUT, $m2 eq (opset: "negate", < @masked) ?? "ok 21\n" !! "not ok 21\n"

print: $^STDOUT, try { ($cpt->mask: "a bad mask") } ?? "not ok 22\n" !! "ok 22\n"

print: $^STDOUT, ($cpt->reval: "2 + 2") == 4 ?? "ok 23\n" !! "not ok 23\n"

$cpt->mask:  <(empty_opset: )
my $t_scalar = $cpt->reval: 'print wantarray ? "not ok 24\n" : "ok 24\n"'
print: $^STDOUT, ($cpt->reval: 'our @ary=(6,7,8);@ary') == 3 ?? "ok 25\n" !! "not ok 25\n"
my @t_array  = $cpt->reval: 'print wantarray ? "ok 26\n" : "not ok 26\n"; (2,3,4)'
print: $^STDOUT, @t_array[2] == 4 ?? "ok 27\n" !! "not ok 27\n"

my $t_scalar2 = $cpt->reval: 'die "foo bar"; 1'
print: $^STDOUT, defined $t_scalar2 ?? "not ok 28\n" !! "ok 28\n"
print: $^STDOUT, $^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/foo bar/ ?? "ok 29\n" !! "not ok 29\n"

# --- rdo

my $t = 30
$^OS_ERROR = 0
my $nosuch = '/non/existant/file.name'
open: my $nosuch_fh, "<", $nosuch
if ($^EVAL_ERROR)
    my $errno  = $^OS_ERROR
    die: "Eek! Attempting to open $nosuch failed, but \$! is still 0" unless $^OS_ERROR
    $^OS_ERROR = 0
    $cpt->rdo: $nosuch
    (print: $^STDOUT, $^OS_ERROR == $errno ?? "ok $t\n" !! (sprintf: "not ok $t # \"$^OS_ERROR\" is \%d (expected \%d)\n", $^OS_ERROR, $errno)); $t++
else
    die: "Eek! Didn't expect $nosuch to be there."

close: $nosuch_fh

# test #31 is gone.
(print: $^STDOUT, "ok $t\n"); $t++

#my $rdo_file = "tmp_rdo.tpl";
#if (open X,">$rdo_file") {
#    print X "999\n";
#    close X;
#    $cpt->permit_only('const', 'leaveeval');
#    print  $cpt->rdo($rdo_file) == 999 ? "ok $t\n" : "not ok $t\n"; $t++;
#    unlink $rdo_file;
#}
#else {
#    print "# test $t skipped, can't open file: $!\nok $t\n"; $t++;
#}


print: $^STDOUT, "ok $last_test\n"
BEGIN { $last_test = 32 }
