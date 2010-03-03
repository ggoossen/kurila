#!./perl -w
#
# testsuite for Data::Dumper
#

use Test::More

# Since Perl 5.8.1 because otherwise hash ordering is really random.
local $Data::Dumper::Sortkeys = 1

use Data::Dumper
use Config
use utf8

$Data::Dumper::Pad = "#"
my $TMAX
my $XS
my $WANT = ''

our (@a, @c, $c, $d, $foo, %foo, @foo, @dogs, %kennel, $mutts, $e, $f, $i,
    @numbers, @strings, $WANT_PL_N, $WANT_PL_S, $WANT_XS_N, $WANT_XS_S,
    $WANT_XS_I, @numbers_s, @numbers_i, @numbers_ni, @numbers_nis, @numbers_ns,
    @strings_s, @strings_i, @strings_is, @strings_n, @strings_ns, @strings_ni,
    @strings_nis, @numbers_is, @numbers_n, $ping, %ping)


sub TEST($string, ?$name)
    my $t = eval $string
    $t =~ s/([A-Z]+)\(0x[0-9a-f]+\)/$1(0xdeadbeef)/g
        if ($WANT =~ m/deadbeef/)

    ok: ($t eq $WANT and not $^EVAL_ERROR), $name
    if ($^EVAL_ERROR)
        diag: "error: $($^EVAL_ERROR->message)"
    elsif ($t ne $WANT)
        diag: "--Expected--\n$WANT\n--Got--\n$t\n"
    

    eval "$t"
    ok: !$^EVAL_ERROR
    diag: $^EVAL_ERROR if $^EVAL_ERROR

    $t = eval $string
    $t =~ s/([A-Z]+)\(0x[0-9a-f]+\)/$1(0xdeadbeef)/g
        if ($WANT =~ m/deadbeef/)
    ok: $t eq $WANT and not $^EVAL_ERROR
    if ($^EVAL_ERROR)
        diag: "error: $($^EVAL_ERROR->message)"
    elsif ($t ne $WANT)
        diag: "--Expected--\n$WANT\n--Got--\n$t\n"
    


sub SKIP_TEST
    my $reason = shift
    :SKIP do
        skip: $reason, 3
    


$TMAX = 8; $XS = 0

plan: tests => $TMAX

is: (Data::Dumper->Dump: \(@: '123xyz{$@%'), \qw(a)), '#$a = "123xyz\{\$\@\%";' . "\n"
is: (Data::Dumper->Dump: \(@: (@: 'abc', 'def')), \(@: 'a')), <<'====' 
#$a = @(:
#     "abc",
#     "def"
#     );
====

is: (Data::Dumper->Dump: \(@: undef), \(@: 'a')), '#$a = undef;' . "\n" 

is: (Data::Dumper->Dump: \(@:  (bless: \(%:  aap => 'noot' ), 'version') ), \(@: 'a')), <<'===='
#$a = bless( \%(:
#              "aap" => "noot"
#            ), "version" );
====

is: (Data::Dumper->Dump: \(@: (%:  aap => 'noot' )), \(@: '*mies')), <<'===='
#%mies = %(:
#        "aap" => "noot"
#        );
====

#XXXif (0) {
#############
#############

@c = @: "c"
$c = \@c
$b = \$%
$a = \@: 1, $b, $c
$b->{+a} = $a
$b->{+b} = $a->[1]
$b->{+c} = $a->[2]

############# 1
##
$WANT = <<'EOT'
#$a = \@(:
#       1,
#       \%(:
#         "a" => $a,
#         "b" => $a->[1],
#         "c" => \@(:
#                  "c"
#                )
#       ),
#       $a->[1]->{"c"}
#     );
#$b = $a->[1];
#$6 = $a->[1]->{"c"};
EOT

TEST: q(Data::Dumper->Dump: \(@: $a,$b,$c), \(@: < qw(a b), 6))
