#!./perl

BEGIN 
    require "test.pl"
our $NUM_SECTS
my @strs = map: { chomp ; $_ }, grep: { !m/^\s*\#/ }, @:  ~< $^DATA
my $out = runperl: progfile => "t/regop.pl", stderr => 1 
# VMS currently embeds linefeeds in the output.
$out =~ s/\cJ//g if $^OS_NAME = 'VMS'
my @tests = grep: { m/\S/ }, split: m/(?=Compiling REx)/, $out
# on debug builds we get an EXECUTING... message in there at the top
shift @tests
    if @tests[0] =~ m/EXECUTING.../

plan:  (nelems @tests) + 2 + ( (nelems @strs) - (nelems: (grep: { !$_ or m/^---/ }, @strs) ))

is:  nelems @tests, $NUM_SECTS
     "Expecting output for $NUM_SECTS patterns" 
ok:  defined $out, 'regop.pl returned something defined' 

$out ||= ""
my $test= 1
foreach my $testout (  @tests )
    my (@:  $pattern )= @: $testout=~m/Compiling REx "([^"]+)"/
    ok:  $pattern, "Pattern for test " . ($test++) 
    my $diaged

    while ((nelems @strs))
        local $_ = shift @strs
        last if !$_
          or m/^---/
        next if m/^\s*#/
        s/^\s+//
        s/\s+$//
        ok:  $testout=~m/\Q$_\E/, "$_: /$pattern/" 
            or do
            !$diaged++ and diag: "$_: /$pattern/\n'$testout'"


# The format below is simple. Each line is an exact
# string that must be found in the output.
# Lines starting the # are comments.
# Lines starting with --- are seperators indicating
# that the tests for this result set are finished.
# If you add a test make sure you update $NUM_SECTS
# the commented output is just for legacy/debugging purposes
BEGIN{ $NUM_SECTS= 6 }

__END__
#Compiling REx "X(A|[B]Q||C|D)Y"
#size 34
#first at 1
#   1: EXACT <X>(3)
#   3: OPEN1(5)
#   5:   TRIE-EXACT(21)
#        [Words:5 Chars:5 Unique:5 States:6 Start-Class:A-D]
#          <A>
#          <BQ>
#          <>
#          <C>
#          <D>
#  21: CLOSE1(23)
#  23: EXACT <Y>(25)
#  25: END(0)
#anchored "X" at 0 floating "Y" at 1..3 (checking floating) minlen 2
#Guessing start of match, REx "X(A|[B]Q||C|D)Y" against "XY"...
#Found floating substr "Y" at offset 1...
#Found anchored substr "X" at offset 0...
#Guessed: match at offset 0
#Matching REx "X(A|[B]Q||C|D)Y" against "XY"
#  Setting an EVAL scope, savestack=140
#   0 <> <XY>              |  1:  EXACT <X>
#   1 <X> <Y>              |  3:  OPEN1
#   1 <X> <Y>              |  5:  TRIE-EXACT
#                                 matched empty string...
#   1 <X> <Y>              | 21:  CLOSE1
#   1 <X> <Y>              | 23:  EXACT <Y>
#   2 <XY> <>              | 25:  END
#Match successful!
#%MATCHED%
#Freeing REx: "X(A|[B]Q||C|D)Y"
Compiling REx "X(A|[B]Q||C|D)Y"
[A-D]
TRIE-EXACT
<BQ>
matched empty string
Match successful!
Found floating substr "Y" at offset 1...
Found anchored substr "X" at offset 0...
Guessed: match at offset 0
checking floating
minlen 2
S:1/6   
W:5
L:0/2
C:5/5
%MATCHED%
---
#Compiling REx "[f][o][o][b][a][r]"
#size 67
#first at 1
#   1: EXACT <foobar>(13)
#  13: END(0)
#anchored "foobar" at 0 (checking anchored isall) minlen 6
#Guessing start of match, REx "[f][o][o][b][a][r]" against "foobar"...
#Found anchored substr "foobar" at offset 0...
#Guessed: match at offset 0
#Freeing REx: "[f][o][o][b][a][r]"
foobar
checking anchored isall
minlen 6
anchored "foobar" at 0
Guessed: match at offset 0
Compiling REx "[f][o][o][b][a][r]"
Freeing REx: "[f][o][o][b][a][r]"
%MATCHED%
---
#Compiling REx ".[XY]."
#size 14
#first at 1
#   1: REG_ANY(2)
#   2: ANYOF[XY](13)
#  13: REG_ANY(14)
#  14: END(0)
#minlen 3
#%FAILED%
#Freeing REx: ".[XY]."
%FAILED%
minlen 3
---
# Compiling REx "(?:ABCP|ABCG|ABCE|ABCB|ABCA|ABCD)"
# Got 164 bytes for offset annotations.
#     TRIE(NATIVE): W:6 C:24 Uq:7 Min:4 Max:4
#       Char : Match Base  Ofs     A   B   C   P   G   E   D
#       State|---------------------------------------------------
#       #   1|       @   7 + 0[    2   .   .   .   .   .   .]
#       #   2|       @   7 + 1[    .   3   .   .   .   .   .]
#       #   3|       @   7 + 2[    .   .   4   .   .   .   .]
#       #   4|       @   A + 0[    9   8   0   5   6   7   A]
#       #   5| W   1 @   0 
#       #   6| W   2 @   0 
#       #   7| W   3 @   0 
#       #   8| W   4 @   0 
#       #   9| W   5 @   0 
#       #   A| W   6 @   0 
# Final program:
#    1: EXACT <ABC>(3)
#    3: TRIEC-EXACT<S:4/10 W:6 L:1/1 C:24/7>[A-EGP](20)
#       <P> 
#       <G> 
#       <E> 
#       <B> 
#       <A> 
#       <D> 
#   20: END(0)
# anchored "ABC" at 0 (checking anchored) minlen 4 
# Offsets: [20]
# 	1:4[3] 3:4[15] 19:32[0] 20:34[0] 
# Guessing start of match in sv for REx "(?:ABCP|ABCG|ABCE|ABCB|ABCA|ABCD)" against "ABCD"
# Found anchored substr "ABC" at offset 0...
# Guessed: match at offset 0
# Matching REx "(?:ABCP|ABCG|ABCE|ABCB|ABCA|ABCD)" against "ABCD"
#    0 <> <ABCD>               |  1:EXACT <ABC>(3)
#    3 <ABC> <D>               |  3:TRIEC-EXACT<S:4/10 W:6 L:1/1 C:24/7>[A-EGP](20)
#    3 <ABC> <D>               |    State:    4 Accepted:    0 Charid:  7 CP:  44 After State:    a
#    4 <ABCD> <>               |    State:    a Accepted:    1 Charid:  6 CP:   0 After State:    0
#                                   got 1 possible matches
#                                   only one match left: #6 <D>
#    4 <ABCD> <>               | 20:END(0)
# Match successful!
# %MATCHED%
# Freeing REx: "(?:ABCP|ABCG|ABCE|ABCB|ABCA|ABCD)"
%MATCHED%
EXACT <ABC>
TRIEC-EXACT
[A-EGP]
only one match left: #6 <D>
S:4/10
W:6
L:1/1
C:24/7
minlen 4
(checking anchored)
anchored "ABC" at 0
---
#Compiling REx "(\\.COM|\\.EXE|\\.BAT|\\.CMD|\\.VBS|\\.VBE|\\.JS|\\.JSE|\\.W"...
#Got 4916 bytes for offset annotations.
#study chunkstudy chunkstudy chunkstudy chunkstudy chunkstudy chunkstudy chunkstudy chunkstudy chunkstudy chunkstudy chunkstudy chunkstudy chunkstudy chunkstudy chunkminlen: 3
#Final program:
#   1: OPEN1 (3)
#   3:   BRANCH (48)
#   4:     ANYOF{i}[.s(# comment
#)] (15)
#  15:     ANYOF{i}[Ccs(# comment
#)] (26)
#  26:     ANYOF{i}[Oos(# comment
#)] (37)
#  37:     ANYOF{i}[Mms(# comment
#)] (611)
#  48:   BRANCH (93)
#  49:     ANYOF{i}[.s(# comment
#)] (60)
#  60:     ANYOF{i}[Ees(# comment
#)] (71)
#  71:     ANYOF{i}[Xxs(# comment
#)] (82)
#  82:     ANYOF{i}[Ees(# comment
#)] (611)
#  93:   BRANCH (138)
#  94:     ANYOF{i}[.s(# comment
#)] (105)
# 105:     ANYOF{i}[Bbs(# comment
#)] (116)
# 116:     ANYOF{i}[Aas(# comment
#)] (127)
# 127:     ANYOF{i}[Tts(# comment
#)] (611)
# 138:   BRANCH (183)
# 139:     ANYOF{i}[.s(# comment
#)] (150)
# 150:     ANYOF{i}[Ccs(# comment
#)] (161)
# 161:     ANYOF{i}[Mms(# comment
#)] (172)
# 172:     ANYOF{i}[Dds(# comment
#)] (611)
# 183:   BRANCH (228)
# 184:     ANYOF{i}[.s(# comment
#)] (195)
# 195:     ANYOF{i}[Vvs(# comment
#)] (206)
# 206:     ANYOF{i}[Bbs(# comment
#)] (217)
# 217:     ANYOF{i}[Sss(# comment
#)] (611)
# 228:   BRANCH (273)
# 229:     ANYOF{i}[.s(# comment
#)] (240)
# 240:     ANYOF{i}[Vvs(# comment
#)] (251)
# 251:     ANYOF{i}[Bbs(# comment
#] (262)
# 262:     ANYOF{i}[Ees(# comment
#)] (611)
# 273:   BRANCH (307)
# 274:     ANYOF{i}[.s(# comment
#)] (285)
# 285:     ANYOF{i}[Jjs(# comment
#)] (296)
# 296:     ANYOF{i}[Sss(# comment
#)] (611)
# 307:   BRANCH (352)
# 308:     ANYOF{i}[.s(# comment
#)] (319)
# 319:     ANYOF{i}[Jjs(# comment
#)] (330)
# 330:     ANYOF{i}[Sss(# comment
#)] (341)
# 341:     ANYOF{i}[Ees(# comment
#)] (611)
# 352:   BRANCH (397)
#353:     ANYOF{i}[.s(# comment
#)] (364)
# 364:     ANYOF{i}[Wws(# comment
#)] (375)
# 375:     ANYOF{i}[Sss(# comment
#)] (386)
# 386:     ANYOF{i}[Ffs(# comment
#)] (611)
# 397:   BRANCH (442)
# 398:     ANYOF{i}[.s(# comment
#)] (409)
# 409:     ANYOF{i}[Wws(# comment
#)] (420)
# 420:     ANYOF{i}[Sss(# comment
#)] (431)
# 431:     ANYOF{i}[Hhs(# comment
#)] (611)
# 442:   BRANCH (487)
# 443:     ANYOF{i}[.s(# comment
#)] (454)
# 454:     ANYOF{i}[Pps(# comment
#)] (465)
# 465:     ANYOF{i}[Yys(# comment
#)] (476)
# 476:     ANYOF{i}[Oos(# comment
#)] (611)
# 487:   BRANCH (532)
# 488:     ANYOF{i}[.s(# comment
#)] (499)
# 499:     ANYOF{i}[Pps(# comment
#)] (510)
# 510:     ANYOF{i}[Yys(# comment
#)] (521)
# 521:     ANYOF{i}[Ccs(# comment
#)] (611)
# 532:   BRANCH (577)
# 533:     ANYOF{i}[.s(# comment
#)] (544)
# 544:     ANYOF{i}[Pps(# comment
#)] (555)
# 555:     ANYOF{i}[Yys(# comment
#)] (566)
# 566:     ANYOF{i}[Wws(# comment
#)] (611)
# 577:   BRANCH (FAIL)
# 578:     ANYOF{i}[.s(# comment
#)] (589)
# 589:     ANYOF{i}[Pps(# comment
#)] (600)
# 600:     ANYOF{i}[Yys(# comment
#)] (611)
# 611: CLOSE1 (613)
# 613: EOL (614)
# 614: END (0)
#floating ""$ at 3..4 (checking floating) minlen 3 
#Guessing start of match in sv for REx "(\\.COM|\\.EXE|\\.BAT|\\.CMD|\\.VBS|\\.VBE|\\.JS|\\.JSE|\\.W"... against "D:dev/perl/ver/28321_/perl.exe"
#Found floating substr ""$ at offset 30...
#Starting position does not contradict /^/m...
#Guessed: match at offset 26
#Matching REx "(\\.COM|\\.EXE|\\.BAT|\\.CMD|\\.VBS|\\.VBE|\\.JS|\\.JSE|\\.W"... against ".exe"
#regtry  26 <21_/perl> <.exe>       |  1:OPEN1(3)
#  26 <21_/perl> <.exe>       |  3:BRANCH(48)
#  26 <21_/perl> <.exe>       |  4:  ANYOF{i}[.s(# comment
#)](15)
#  27 <21_/perl.> <exe>       | 15:  ANYOF{i}[Ccs(# comment
#)](26)
#                                    failed...
#  26 <21_/perl> <.exe>       | 48:BRANCH(93)
#  26 <21_/perl> <.exe>       | 49:  ANYOF{i}[.s(# comment
#)](60)
#  27 <21_/perl.> <exe>       | 60:  ANYOF{i}[Ees(# comment
#)](71)
#  28 <21_/perl.e> <xe>       | 71:  ANYOF{i}[Xxs(# comment
#)](82)
#  29 <21_/perl.ex> <e>       | 82:  ANYOF{i}[Ees(# comment
#)](611)
#  30 <21_/perl.exe> <>       |611:  CLOSE1(613)
#  30 <21_/perl.exe> <>       |613:  EOL(614)
#  30 <21_/perl.exe> <>       |614:  END(0)
#Match successful!
#POP STATE(1)
#%MATCHED%
#Freeing REx: "(\\.COM|\\.EXE|\\.BAT|\\.CMD|\\.VBS|\\.VBE|\\.JS|\\.JSE|\\."......
%MATCHED%
floating ""$ at 3..4 (checking floating)
ANYOF{i}[Ccs(# comment
Guessed: match at offset 26
---
#Compiling REx "[q]"
#size 12 nodes Got 100 bytes for offset annotations.
#first at 1
#Final program:
#   1: EXACT <q>(3)
#   3: END(0)
#anchored "q" at 0 (checking anchored isall) minlen 1
#Offsets: [12]
#        1:1[3] 3:4[0]
#Guessing start of match, REx "[q]" against "q"...
#Found anchored substr "q" at offset 0...
#Guessed: match at offset 0
#%MATCHED%
#Freeing REx: "[q]"
%MATCHED%        
