#!perl

my $dprofpp = "../utils/dprofpp";

BEGIN { require './test.pl'; }

plan 1;

use IO::Handle;

open my $tmon, "> tmon.out" or die;
$tmon->print(<<'TMONOUT');
#fOrTyTwO
$hz=100;
$XS_VERSION='DProf 20050603.00';
# All values are given in HZ
$over_utime=4; $over_stime=0; $over_rtime=3;
$over_tests=10000;
$rrun_utime=1; $rrun_stime=0; $rrun_rtime=0;
$total_marks=8                                                                                                                                                                                     

PART2
@ 1 0 0
& 2 main bar
+ 2
- 2
& 3 main baz
+ 3
+ 2
- 2
& 4 main foo
+ 4
/ 4
/ 3
TMONOUT
close $tmon;

is runperl(progfile => $dprofpp), <<'OUTPUT';
Total Elapsed Time = -1.6e-05 Seconds
  User+System Time = 0.009984 Seconds
Exclusive Times
%Time ExclSec CumulS #Calls sec/call Csec/c  Name
 0.00  -0.000 -0.000      1  -0.0000      -  main::foo
 0.00  -0.000 -0.000      2  -0.0000      -  main::bar
 0.00  -0.000 -0.000      1  -0.0000      -  main::baz
OUTPUT
