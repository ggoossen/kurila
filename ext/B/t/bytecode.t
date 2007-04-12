#!./perl

BEGIN {
    if ($^O eq 'VMS') {
       print "1..0 # skip - Bytecode/ByteLoader doesn't work on VMS\n";
       exit 0;
    }
    chdir 't' if -d 't';
    @INC = qw(../lib);
    require './test.pl'; # for run_perl()
}
use strict;

my $test = 'bytecode.pl';
END { 1 while unlink $test, "${test}c" }

undef $/;
my @tests = split /\n###+\n/, <DATA>;

print "1..".($#tests+1)."\n";

my $cnt = 1;

for (@tests) {
    my $got;
    my ($script, $expect) = split />>>+\n/;
    $expect =~ s/\n$//;
    open T, ">$test"; print T $script; close T;
    $got = run_perl(switches => [ "-MO=Bytecode,-H,-o${test}c" ],
		    verbose  => 0, # for debugging
		    stderr   => 1, # to capture the "bytecode.pl syntax ok"
		    progfile => $test);
    unless ($?) {
	1 while unlink($test); # nuke the .pl
	$got = run_perl(progfile => "${test}c"); # run the .plc
	unless ($?) {
	    if ($got =~ /^$expect$/) {
		print "ok $cnt\n";
		next;
	    } else {
		print <<"EOT"; next;
not ok $cnt
--------- SCRIPT
$script
--------- GOT
$got
--------- EXPECT
$expect
----------------

EOT
	    }
	}
    }
    print <<"EOT";
--------- SCRIPT
$script
--------- $?
$got
EOT
} continue {
    $cnt++;
}

__DATA__

print 'hi'
>>>>
hi
############################################################
for (1,2,3) { print if /\d/ }
>>>>
123
############################################################
$_ = "xyxyx"; %j=(1,2); s/x/$j{print('z')}/ge; print $_
>>>>
zzz2y2y2
############################################################
$_ = "xyxyx"; %j=(1,2); s/x/$j{print('z')}/g; print $_
>>>>
z2y2y2
############################################################
split /a/,"bananarama"; print @_
>>>>
bnnrm
############################################################
{ package P; sub x { print 'ya' } x }
>>>>
ya
############################################################
@z = split /:/,"b:r:n:f:g"; print @z
>>>>
brnfg
############################################################
sub AUTOLOAD { print 1 } &{"a"}()
>>>>
1
############################################################
my $l = 3; $x = sub { print $l }; &$x
>>>>
3
############################################################
my $i = 1;
my $foo = sub {$i = shift if @_};
&$foo(3);
############################################################
$_="\xff\xff"; use utf8; utf8::encode $_; print $_
>>>>
\xc3\xbf\xc3\xbf
############################################################
$x="Cannot use"; print index $x, "Can"
>>>>
0
############################################################
my $i=6; eval "print \$i\n"
>>>>
6
############################################################
BEGIN { %h=(1=>2,3=>4) } print $h{3}
>>>>
4
############################################################
open our $T,"a"
############################################################
print <DATA>
__DATA__
a
b
>>>>
a
b
############################################################
BEGIN { tie @a, __PACKAGE__; sub TIEARRAY { bless{} } sub FETCH { 1 } }
print $a[1]
>>>>
1
############################################################
my $i=3; print 1 .. $i
>>>>
123
############################################################
my $h = { a=>3, b=>1 }; print sort {$h->{$a} <=> $h->{$b}} keys %$h
>>>>
ba
############################################################
print sort { my $p; $b <=> $a } 1,4,3
>>>>
431
