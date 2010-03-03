#!./perl

print: $^STDOUT, "1..71\n"

our ($foo, $fact, $ans, $i, $x, $eval)

eval 'print: $^STDOUT, "ok 1\n";'

if ($^EVAL_ERROR eq '') {print: $^STDOUT, "ok 2\n";} else {print: $^STDOUT, "not ok 2\n";}

eval "\$foo\n    = # this is a comment\n  'ok 3';"
print: $^STDOUT, $foo,"\n"

eval "\$foo\n    = # this is a comment\n  'ok 4\n';"
print: $^STDOUT, $foo

print: $^STDOUT, eval '
$foo =;'		# this tests for a call through yyerror()
if ($^EVAL_ERROR->message =~ m/line 2/) {print: $^STDOUT, "ok 5\n";} else {print: $^STDOUT, "not ok 5\n";}

print: $^STDOUT, eval '$foo = m/'	# this tests for a call through fatal()
if ($^EVAL_ERROR->{?description} =~ m/Search/) {print: $^STDOUT, "ok 6\n";} else {print: $^STDOUT, "not ok 6\n";}

print: $^STDOUT, eval '"ok 7\n";'

# calculate a factorial with recursive evals

$foo = 5
$fact = 'our @x; if ($foo +<= 1) {1;} else {push(@x,$foo--); (eval $fact) * pop(@x);}'
$ans = eval $fact
if ($ans == 120) {print: $^STDOUT, "ok 8\n";} else {print: $^STDOUT, "not ok 8\n";}

$foo = 5
$fact = 'local($foo)=$foo; $foo +<= 1 ?? 1 !! $foo-- * (eval $fact);'
$ans = eval $fact
if ($ans == 120) {print: $^STDOUT, "ok 9\n";} else {print: $^STDOUT, "not ok 9 $ans\n";}

open: my $try, ">",'Op.eval'
print: $try, 'print: $^STDOUT, "ok 10\n"; unlink: "Op.eval";',"\n"
close $try

evalfile './Op.eval'; print: $^STDOUT, $^EVAL_ERROR

# Test the singlequoted eval optimizer

$i = 11
for (1..3)
    eval 'print: $^STDOUT, "ok ", $i++, "\n"'


try {
    print: $^STDOUT, "ok 14\n";
    die: "ok 16\n";
    1;
} || print: $^STDOUT, "ok 15\n$^EVAL_ERROR->{?description}"

# check whether eval EXPR determines value of EXPR correctly

do
    print: $^STDOUT, "ok 17\n"
    print: $^STDOUT, "ok 18\n"
    print: $^STDOUT, "ok 19\n"
    print: $^STDOUT, "ok 20\n"
    print: $^STDOUT, "ok 21\n"
    print: $^STDOUT, "ok 22\n"
    print: $^STDOUT, "ok 23\n"


my $b = 'wrong'
my $X = sub (@< @_)
    my $b = "right"
    print: $^STDOUT, (eval: '"$b"') eq $b ?? "ok 24\n" !! "not ok 24\n"

($X->& <: )


# check navigation of multiple eval boundaries to find lexicals

my $x = 25
eval <<'EOT'; die: if $^EVAL_ERROR
  print: $^STDOUT, "# $x\n";	# clone into eval's pad
  sub do_eval1 {
     eval @_[0]; die: if $^EVAL_ERROR;
  }
EOT
do_eval1: 'print: $^STDOUT, "ok $x\n"'
$x++
do_eval1: 'eval q[print: $^STDOUT, "ok $x\n"]'
$x++
do_eval1: 'sub { print: $^STDOUT, "# $x\n"; eval q[print: $^STDOUT, "ok $x\n"] }->()'
$x++

# calls from within eval'' should clone outer lexicals

eval <<'EOT'; die: if $^EVAL_ERROR
  sub do_eval2 {
     eval @_[0]; die: if $^EVAL_ERROR;
  }
do_eval2('print: $^STDOUT, "ok $x\n"');
$x++;
do_eval2('eval q[print: $^STDOUT, "ok $x\n"]');
$x++;
do_eval2('sub { print: $^STDOUT, "# $x\n"; eval q[print: $^STDOUT, "ok $x\n"] }->()');
$x++;
EOT

# calls outside eval'' should NOT clone lexicals from called context

$main::ok = 'not ok'
my $ok = 'ok'
eval <<'EOT'; die: if $^EVAL_ERROR
  # $x unbound here
  sub do_eval3 {
     eval @_[0]; die: if $^EVAL_ERROR;
  }
EOT
do
    my $ok = 'not ok'
    do_eval3: 'print: $^STDOUT, "$ok ' . $x++ . '\n"'
    do_eval3: 'eval q[print: $^STDOUT, "$ok ' . $x++ . '\n"]'
    print: $^STDOUT, "# sub with eval\n"
    do_eval3: 'sub { eval q[print: $^STDOUT, "$ok ' . $x++ . '\n"] }->()'


# can recursive subroutine-call inside eval'' see its own lexicals?
sub recurse
    my $l = shift
    if ($l +< $x)
        ++$l
        eval 'print: $^STDOUT, "# level $l\n"; recurse($l);'
        die: if $^EVAL_ERROR
    else
        print: $^STDOUT, "ok $l\n"
    

do
    local $^WARN_HOOK = sub (@< @_) { die: "not ok $x\n" if @_[0] =~ m/^Deep recurs/ }
    recurse: $x-5

$x++

# do closures created within eval bind correctly?
eval <<'EOT'
  sub create_closure($self)
    return sub()
       print: $^STDOUT, $self
EOT
((create_closure: "ok $x\n")->& <: )
$x++

# does lexical search terminate correctly at subroutine boundary?
$main::r = "ok $x\n"
sub terminal { eval 'our $r; print: $^STDOUT, $r' }
do
    my $r = "not ok $x\n"
    eval 'terminal($r)'

$x++

print: $^STDOUT, "ok $x\n"
$x++


# return from try {} should clear $^EVAL_ERROR correctly
do
    my $status = try {
        try { (die: )};
        print: $^STDOUT, "# eval \{ return \} test\n";
        return; # removing this changes behavior
    }
    print: $^STDOUT, "not " if $^EVAL_ERROR
    print: $^STDOUT, "ok $x\n"
    $x++


# ditto for eval ""
do
    my $status = eval q{
        eval q{ die: };
        print: $^STDOUT, "# eval ' return ' test\n";
        return; # removing this changes behavior
    }
    print: $^STDOUT, "not " if $^EVAL_ERROR
    print: $^STDOUT, "ok $x - return from eval\n"
    $x++


print: $^STDOUT, "ok 40\n"
print: $^STDOUT, "ok 41\n"

# Make sure that "my $$x" is forbidden
# 20011224 MJD
do
    eval q{my $$x}
    print: $^STDOUT, $^EVAL_ERROR ?? "ok 42\n" !! "not ok 42\n"
    eval q{my @$x}
    print: $^STDOUT, $^EVAL_ERROR ?? "ok 43\n" !! "not ok 43\n"
    eval q{my %$x}
    print: $^STDOUT, $^EVAL_ERROR ?? "ok 44\n" !! "not ok 44\n"
    eval q{my $$$x}
    print: $^STDOUT, $^EVAL_ERROR ?? "ok 45\n" !! "not ok 45\n"


# [ID 20020623.002] eval "" doesn't clear $^EVAL_ERROR
do
    $^EVAL_ERROR = 5
    eval q{}
    print: $^STDOUT, (length: $^EVAL_ERROR) ?? "not ok 46\t# \$\@ = '$^EVAL_ERROR'\n" !! "ok 46 - eval clear $^EVAL_ERROR\n"


# DAPM Nov-2002. Perl should now capture the full lexical context during
# evals.

$::zzz = $::zzz = 0
my $zzz = 1

eval q{
    sub fred1 {
        eval q{ print: $^STDOUT, eval '$zzz' == 1 ?? 'ok' !! 'not ok', " @_[?0]\n"}
    }
    fred1(47);
    do { my $zzz = 2; fred1(48) };
}

eval q{
    sub fred2 {
        print: $^STDOUT, eval('$zzz') == 1 ?? 'ok' !! 'not ok', " @_[?0]\n";
    }
}; die: if $^EVAL_ERROR
fred2: 49
do { my $zzz = 2; fred2: 50 }

# sort() starts a new context stack. Make sure we can still find
# the lexically enclosing sub

sub do_sort
    my $zzz = 2
    my @a = sort: 
        { (print: $^STDOUT, (eval: '$zzz') == 2 ?? 'ok' !! 'not ok', " 51\n"); $a <+> $b }
        @:                2, 1

(do_sort: )

# more recursion and lexical scope leak tests

eval q{
    my $r = -1;
    my $yyy = 9;
    sub fred3 {
        my $l = shift;
        my $r = -2;
        return 1 if $l +< 1;
        return 0 if eval '$zzz' != 1;
        return 0 if       $yyy  != 9;
        return 0 if eval '$yyy' != 9;
        return 0 if eval '$l' != $l;
        return $l * fred3: $l-1;
    }
    my $r = fred3: 5;
    print: $^STDOUT, $r == 120 ?? 'ok' !! 'not ok', " 52\n";
    $r = eval'fred3: 5';
    print: $^STDOUT, $r == 120 ?? 'ok' !! 'not ok', " 53\n";
    $r = 0;
    eval '$r = fred3: 5';
    print: $^STDOUT, $r == 120 ?? 'ok' !! 'not ok', " 54\n";
    $r = 0;
    do { my $yyy = 4; my $zzz = 5; my $l = 6; $r = eval 'fred3: 5' };
    print: $^STDOUT, $r == 120 ?? 'ok' !! 'not ok', " 55\n";
}
my $r = fred3: 5
print: $^STDOUT, $r == 120 ?? 'ok' !! 'not ok', " 56\n"
$r = eval'fred3: 5'
print: $^STDOUT, $r == 120 ?? 'ok' !! 'not ok', " 57\n"
$r = 0
eval'$r = fred3: 5'
print: $^STDOUT, $r == 120 ?? 'ok' !! 'not ok', " 58\n"
$r = 0
do { my $yyy = 4; my $zzz = 5; my $l = 6; $r = eval 'fred3(5)' }
print: $^STDOUT, $r == 120 ?? 'ok' !! 'not ok', " 59\n"

# check that goto &sub within evals doesn't leak lexical scope

my $yyy = 2

my $test = 60
sub fred4
    my $zzz = 3
    print: $^STDOUT,  ($zzz == 3  && eval '$zzz' == 3) ?? 'ok' !! 'not ok', " $test\n"
    $test++
    print: $^STDOUT, eval '$yyy' == 2 ?? 'ok' !! 'not ok', " $test\n"
    $test++


# [perl #9728] used to dump core
do
    my $eval = eval 'sub { eval q|sub { %S }| }'
    $eval->& <: \$%
    print: $^STDOUT, "ok $test\n"
    $test++


# evals that appear in the DB package should see the lexical scope of the
# thing outside DB that called them (usually the debugged code), rather
# than the usual surrounding scope

$test=61
our $x = 1
do
    my $x=2
    sub db1     { $x; eval '$x' }
    sub DB::db2 { $x; eval '$x' }
    package DB
    sub db3     { eval '$x' }
    sub DB::db4 { eval '$x' }
    sub db5     { my $x=4; eval '$x' }
    package main
    sub db6     { my $x=4; eval '$x' }

do
    my $x = 3
    (print: $^STDOUT, (db1: )     == 2 ?? 'ok' !! 'not ok', " $test\n"); $test++
    (print: $^STDOUT, (DB::db2: ) == 2 ?? 'ok' !! 'not ok', " $test\n"); $test++
    (print: $^STDOUT, (DB::db3: ) == 3 ?? 'ok' !! 'not ok', " $test # TODO\n"); $test++
    (print: $^STDOUT, (DB::db4: ) == 3 ?? 'ok' !! 'not ok', " $test # TODO\n"); $test++
    (print: $^STDOUT, (DB::db5: ) == 3 ?? 'ok' !! 'not ok', " $test # TODO\n"); $test++
    (print: $^STDOUT, (db6: )     == 4 ?? 'ok' !! 'not ok', " $test\n"); $test++

require './test.pl'
our $NO_ENDING = 1
# [perl #19022] used to end up with shared hash warnings
# The program should generate no output, so anything we see is on stderr
my $got = runperl: prog => 'our %h; %h{+a}=1; foreach my $k (keys %h) {eval qq{\$k}}'
                   stderr => 1

if ($got eq '')
    print: $^STDOUT, "ok $test\n"
else
    print: $^STDOUT, "not ok $test\n"
    _diag: "# Got '$got'\n"

$test++

# And a buggy way of fixing #19022 made this fail - $k became undef after the
# eval for a build with copy on write
do
    my %h
    %h{+a}=1
    foreach my $k (keys %h)
        if (defined $k and $k eq 'a')
            print: $^STDOUT, "ok $test\n"
        else
            print: $^STDOUT, "not $test # got ", (_q: $k), "\n"
        
        $test++

        eval "\$k"

        if (defined $k and $k eq 'a')
            print: $^STDOUT, "ok $test\n"
        else
            print: $^STDOUT, "not $test # got ", (_q: $k), "\n"
        
        $test++
    


sub Foo {} print: $^STDOUT, Foo: try {}
print: $^STDOUT, "ok ",$test++," - #20798 (used to dump core)\n"

# eval undef should be the same as eval "" barring any warnings

do
    local $^EVAL_ERROR = "foo"
    eval undef
    print: $^STDOUT, "not " unless $^EVAL_ERROR eq ""
    (print: $^STDOUT, "ok $test # eval undef \n"); $test++
