#!./perl

# $RCSfile: pat.t,v $$Revision: 4.1 $$Date: 92/08/07 18:28:12 $

print "1..97\n";

$x = "abc\ndef\n";

if ($x =~ /^abc/) {print "ok 1\n";} else {print "not ok 1\n";}
if ($x !~ /^def/) {print "ok 2\n";} else {print "not ok 2\n";}

$* = 1;
if ($x =~ /^def/) {print "ok 3\n";} else {print "not ok 3\n";}
$* = 0;

$_ = '123';
if (/^([0-9][0-9]*)/) {print "ok 4\n";} else {print "not ok 4\n";}

if ($x =~ /^xxx/) {print "not ok 5\n";} else {print "ok 5\n";}
if ($x !~ /^abc/) {print "not ok 6\n";} else {print "ok 6\n";}

if ($x =~ /def/) {print "ok 7\n";} else {print "not ok 7\n";}
if ($x !~ /def/) {print "not ok 8\n";} else {print "ok 8\n";}

if ($x !~ /.def/) {print "ok 9\n";} else {print "not ok 9\n";}
if ($x =~ /.def/) {print "not ok 10\n";} else {print "ok 10\n";}

if ($x =~ /\ndef/) {print "ok 11\n";} else {print "not ok 11\n";}
if ($x !~ /\ndef/) {print "not ok 12\n";} else {print "ok 12\n";}

$_ = 'aaabbbccc';
if (/(a*b*)(c*)/ && $1 eq 'aaabbb' && $2 eq 'ccc') {
	print "ok 13\n";
} else {
	print "not ok 13\n";
}
if (/(a+b+c+)/ && $1 eq 'aaabbbccc') {
	print "ok 14\n";
} else {
	print "not ok 14\n";
}

if (/a+b?c+/) {print "not ok 15\n";} else {print "ok 15\n";}

$_ = 'aaabccc';
if (/a+b?c+/) {print "ok 16\n";} else {print "not ok 16\n";}
if (/a*b+c*/) {print "ok 17\n";} else {print "not ok 17\n";}

$_ = 'aaaccc';
if (/a*b?c*/) {print "ok 18\n";} else {print "not ok 18\n";}
if (/a*b+c*/) {print "not ok 19\n";} else {print "ok 19\n";}

$_ = 'abcdef';
if (/bcd|xyz/) {print "ok 20\n";} else {print "not ok 20\n";}
if (/xyz|bcd/) {print "ok 21\n";} else {print "not ok 21\n";}

if (m|bc/*d|) {print "ok 22\n";} else {print "not ok 22\n";}

if (/^$_$/) {print "ok 23\n";} else {print "not ok 23\n";}

$* = 1;		# test 3 only tested the optimized version--this one is for real
if ("ab\ncd\n" =~ /^cd/) {print "ok 24\n";} else {print "not ok 24\n";}
$* = 0;

$XXX{123} = 123;
$XXX{234} = 234;
$XXX{345} = 345;

@XXX = ('ok 25','not ok 25', 'ok 26','not ok 26','not ok 27');
while ($_ = shift(XXX)) {
    ?(.*)? && (print $1,"\n");
    /not/ && reset;
    /not ok 26/ && reset 'X';
}

while (($key,$val) = each(%XXX)) {
    print "not ok 27\n";
    exit;
}

print "ok 27\n";

'cde' =~ /[^ab]*/;
'xyz' =~ //;
if ($& eq 'xyz') {print "ok 28\n";} else {print "not ok 28\n";}

$foo = '[^ab]*';
'cde' =~ /$foo/;
'xyz' =~ //;
if ($& eq 'xyz') {print "ok 29\n";} else {print "not ok 29\n";}

$foo = '[^ab]*';
'cde' =~ /$foo/;
'xyz' =~ /$null/;
if ($& eq 'xyz') {print "ok 30\n";} else {print "not ok 30\n";}

$_ = 'abcdefghi';
/def/;		# optimized up to cmd
if ("$`:$&:$'" eq 'abc:def:ghi') {print "ok 31\n";} else {print "not ok 31\n";}

/cde/ + 0;	# optimized only to spat
if ("$`:$&:$'" eq 'ab:cde:fghi') {print "ok 32\n";} else {print "not ok 32\n";}

/[d][e][f]/;	# not optimized
if ("$`:$&:$'" eq 'abc:def:ghi') {print "ok 33\n";} else {print "not ok 33\n";}

$_ = 'now is the {time for all} good men to come to.';
/ {([^}]*)}/;
if ($1 eq 'time for all') {print "ok 34\n";} else {print "not ok 34 $1\n";}

$_ = 'xxx {3,4}  yyy   zzz';
print /( {3,4})/ ? "ok 35\n" : "not ok 35\n";
print $1 eq '   ' ? "ok 36\n" : "not ok 36\n";
print /( {4,})/ ? "not ok 37\n" : "ok 37\n";
print /( {2,3}.)/ ? "ok 38\n" : "not ok 38\n";
print $1 eq '  y' ? "ok 39\n" : "not ok 39\n";
print /(y{2,3}.)/ ? "ok 40\n" : "not ok 40\n";
print $1 eq 'yyy ' ? "ok 41\n" : "not ok 41\n";
print /x {3,4}/ ? "not ok 42\n" : "ok 42\n";
print /^xxx {3,4}/ ? "not ok 43\n" : "ok 43\n";

$_ = "now is the time for all good men to come to.";
@words = /(\w+)/g;
print join(':',@words) eq "now:is:the:time:for:all:good:men:to:come:to"
    ? "ok 44\n"
    : "not ok 44\n";

@words = ();
while (/\w+/g) {
    push(@words, $&);
}
print join(':',@words) eq "now:is:the:time:for:all:good:men:to:come:to"
    ? "ok 45\n"
    : "not ok 45\n";

@words = ();
pos = 0;
while (/to/g) {
    push(@words, $&);
}
print join(':',@words) eq "to:to"
    ? "ok 46\n"
    : "not ok 46 `@words'\n";

pos $_ = 0;
@words = /to/g;
print join(':',@words) eq "to:to"
    ? "ok 47\n"
    : "not ok 47 `@words'\n";

$_ = "abcdefghi";

$pat1 = 'def';
$pat2 = '^def';
$pat3 = '.def.';
$pat4 = 'abc';
$pat5 = '^abc';
$pat6 = 'abc$';
$pat7 = 'ghi';
$pat8 = '\w*ghi';
$pat9 = 'ghi$';

$t1=$t2=$t3=$t4=$t5=$t6=$t7=$t8=$t9=0;

for $iter (1..5) {
    $t1++ if /$pat1/o;
    $t2++ if /$pat2/o;
    $t3++ if /$pat3/o;
    $t4++ if /$pat4/o;
    $t5++ if /$pat5/o;
    $t6++ if /$pat6/o;
    $t7++ if /$pat7/o;
    $t8++ if /$pat8/o;
    $t9++ if /$pat9/o;
}

$x = "$t1$t2$t3$t4$t5$t6$t7$t8$t9";
print $x eq '505550555' ? "ok 48\n" : "not ok 48 $x\n";

$xyz = 'xyz';
print "abc" =~ /^abc$|$xyz/ ? "ok 49\n" : "not ok 49\n";

# perl 4.009 says "unmatched ()"
eval '"abc" =~ /a(bc$)|$xyz/; $result = "$&:$1"';
print $@ eq "" ? "ok 50\n" : "not ok 50\n";
print $result eq "abc:bc" ? "ok 51\n" : "not ok 51\n";


$_="abcfooabcbar";
$x=/abc/g;
print $` eq "" ? "ok 52\n" : "not ok 52\n" if $x;
$x=/abc/g;
print $` eq "abcfoo" ? "ok 53\n" : "not ok 53\n" if $x;
$x=/abc/g;
print $x == 0 ? "ok 54\n" : "not ok 54\n";
pos = 0;
$x=/ABC/gi;
print $` eq "" ? "ok 55\n" : "not ok 55\n" if $x;
$x=/ABC/gi;
print $` eq "abcfoo" ? "ok 56\n" : "not ok 56\n" if $x;
$x=/ABC/gi;
print $x == 0 ? "ok 57\n" : "not ok 57\n";
pos = 0;
$x=/abc/g;
print $' eq "fooabcbar" ? "ok 58\n" : "not ok 58\n" if $x;
$x=/abc/g;
print $' eq "bar" ? "ok 59\n" : "not ok 59\n" if $x;
$_ .= '';
@x=/abc/g;
print scalar @x == 2 ? "ok 60\n" : "not ok 60\n";

$_ = "abdc";
pos $_ = 2;
/\Gc/gc;
print "not " if (pos $_) != 2;
print "ok 61\n";
/\Gc/g;
print "not " if defined pos $_;
print "ok 62\n";

$out = 1;
'abc' =~ m'a(?{ $out = 2 })b';
print "not " if $out != 2;
print "ok 63\n";

$out = 1;
'abc' =~ m'a(?{ $out = 3 })c';
print "not " if $out != 1;
print "ok 64\n";

$_ = 'foobar1 bar2 foobar3 barfoobar5 foobar6';
@out = /(?<!foo)bar./g;
print "not " if "@out" ne 'bar2 barf';
print "ok 65\n";

# Long Monsters
$test = 66;
for $l (125, 140, 250, 270, 300000, 30) { # Ordered to free memory
  $a = 'a' x $l;
  print "# length=$l\nnot " unless "ba$a=" =~ /a$a=/;
  print "ok $test\n";
  $test++;
  
  print "not " if "b$a=" =~ /a$a=/;
  print "ok $test\n";
  $test++;
}

# 20000 nodes, each taking 3 words per string, and 1 per branch
$long_constant_len = join '|', 12120 .. 32645;
$long_var_len = join '|', 8120 .. 28645;
%ans = ( 'ax13876y25677lbc' => 1,
	 'ax13876y25677mcb' => 0, # not b.
	 'ax13876y35677nbc' => 0, # Num too big
	 'ax13876y25677y21378obc' => 1,
	 'ax13876y25677y21378zbc' => 0,	# Not followed by [k-o]
	 'ax13876y25677y21378y21378kbc' => 1,
	 'ax13876y25677y21378y21378kcb' => 0, # Not b.
	 'ax13876y25677y21378y21378y21378kbc' => 0, # 5 runs
       );

for ( keys %ans ) {
  print "# const-len `$_' not =>  $ans{$_}\nnot " 
    if $ans{$_} xor /a(?=([yx]($long_constant_len)){2,4}[k-o]).*b./o;
  print "ok $test\n";
  $test++;
  print "# var-len   `$_' not =>  $ans{$_}\nnot " 
    if $ans{$_} xor /a(?=([yx]($long_var_len)){2,4}[k-o]).*b./o;
  print "ok $test\n";
  $test++;
}

$_ = " a (bla()) and x(y b((l)u((e))) and b(l(e)e)e";
$expect = "(bla()) ((l)u((e))) (l(e)e)";

sub matchit { 
  m'
     (
       \( 
       (?{ $c = 1 })		# Initialize
       (?:
	 (?(?{ $c == 0 })       # PREVIOUS iteration was OK, stop the loop
	   (?!
	   )			# Fail: will unwind one iteration back
	 )	    
	 (?:
	   [^()]+		# Match a big chunk
	   (?=
	     [()]
	   )			# Do not try to match subchunks
	 |
	   \( 
	   (?{ ++$c })
	 |
	   \) 
	   (?{ --$c })
	 )
       )+			# This may not match with different subblocks
     )
     (?(?{ $c != 0 })
       (?!
       )			# Fail
     )				# Otherwise the chunk 1 may succeed with $c>0
   'xg;
}

push @ans, $res while $res = matchit;

print "# ans='@ans'\n# expect='$expect'\nnot " if "@ans" ne "1 1 1";
print "ok $test\n";
$test++;

@ans = matchit;

print "# ans='@ans'\n# expect='$expect'\nnot " if "@ans" ne $expect;
print "ok $test\n";
$test++;

@ans = ('a/b' =~ m%(.*/)?(.*)%);	# Stack may be bad
print "not " if "@ans" ne 'a/ b';
print "ok $test\n";
$test++;

$code = '$blah = 45';
$blah = 12;
/(?{$code})/;			
print "not " if $blah != 45;
print "ok $test\n";
$test++;

