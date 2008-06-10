#!perl

BEGIN {
    if (%ENV{PERL_CORE}){
	push @INC, '../ext/B/t';
    } else {
	unshift @INC, 't';
	push @INC, "../../t";
    }
    require Config;
    if ((%Config::Config{'extensions'} !~ m/\bB\b/) ){
        print "1..0 # Skip -- Perl configured without B module\n";
        exit 0;
    }
    # require 'test.pl'; # now done by OptreeCheck
}
use OptreeCheck;
use Config;
plan tests => 9;

SKIP: {
skip "no perlio in this build", 11 unless %Config::Config{useperlio};

pass("SORT OPTIMIZATION");

our @a;
checkOptree ( name	=> 'sub {sort @a}',
	      code	=> sub {sort @a},
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 424 optree_sort.t:14) v
# 2  <0> pushmark s
# 3  <#> gv[*a] s
# 4  <1> rv2av[t2] lK/1
# 5  <@> sort K
# 6  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 424 optree_sort.t:14) v
# 2  <0> pushmark s
# 3  <$> gv(*a) s
# 4  <1> rv2av[t1] lK/1
# 5  <@> sort K
# 6  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name => 'sort our @a',
	      prog => 'sort our @a',
	      errs => \@( 'Useless use of sort in void context at -e line 1.',
			),
	      bcopts => '-exec',
	      strip_open_hints => 1,
	      expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <0> enter 
2  <;> nextstate(main 1 -e:1) v:{
3  <0> pushmark s
4  <#> gv[*a] s
5  <1> rv2av[t2] lK/OURINTR,1
6  <@> sort vK
7  <@> leave[1 ref] vKP/REFC
EOT_EOT
# 1  <0> enter 
# 2  <;> nextstate(main 1 -e:1) v:{
# 3  <0> pushmark s
# 4  <$> gv(*a) s
# 5  <1> rv2av[t1] lK/OURINTR,1
# 6  <@> sort vK
# 7  <@> leave[1 ref] vKP/REFC
EONT_EONT

checkOptree ( name	=> 'sub {our @a; @a = sort @a}',
	      code	=> sub {our @a; @a = sort @a},
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <;> nextstate(main -438 optree.t:244) v
2  <0> pushmark s
3  <0> pushmark s
4  <#> gv[*a] s
5  <1> rv2av[t4] lK/1
6  <@> sort lK
7  <0> pushmark s
8  <#> gv[*a] s
9  <1> rv2av[t2] lKRM*/OURINTR,1
a  <2> aassign[t5] KS/COMMON
b  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 652 optree_sort.t:71) v
# 2  <$> gv(*a) s
# 3  <1> rv2av[t2] vK/OURINTR,1
# 4  <;> nextstate(main 653 optree_sort.t:72) v
# 5  <0> pushmark s
# 6  <0> pushmark s
# 7  <$> gv(*a) s
# 8  <1> rv2av[t4] lK/1
# 9  <@> sort lK
# a  <0> pushmark s
# b  <$> gv(*a) s
# c  <1> rv2av[t3] lKRM*/1
# d  <2> aassign[t5] KS/COMMON
# e  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> 'sub {our @a; @a = sort @a; reverse @a}',
	      code	=> sub {our @a; @a = sort @a; reverse @a},
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <;> nextstate(main -438 optree.t:286) v
2  <0> pushmark s
3  <0> pushmark s
4  <#> gv[*a] s
5  <1> rv2av[t4] lKRM*/1
6  <@> sort lK/INPLACE
7  <;> nextstate(main -438 optree.t:288) v
8  <0> pushmark s
9  <#> gv[*a] s
a  <1> rv2av[t7] lK/1
b  <@> reverse[t8] K/1
c  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 654 optree_sort.t:104) v
# 2  <$> gv(*a) s
# 3  <1> rv2av[t2] vK/OURINTR,1
# 4  <;> nextstate(main 655 optree_sort.t:105) v
# 5  <0> pushmark s
# 6  <0> pushmark s
# 7  <$> gv(*a) s
# 8  <1> rv2av[t4] lKRM*/1
# 9  <@> sort lK/INPLACE
# a  <;> nextstate(main 655 optree_sort.t:105) v:{
# b  <0> pushmark s
# c  <$> gv(*a) s
# d  <1> rv2av[t6] lK/1
# e  <@> reverse[t7] K/1
# f  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> 'sub {my @a; @a = sort @a}',
	      code	=> sub {my @a; @a = sort @a},
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <;> nextstate(main -437 optree.t:254) v
2  <0> padav[@a:-437,-436] vM/LVINTRO
3  <;> nextstate(main -436 optree.t:256) v
4  <0> pushmark s
5  <0> pushmark s
6  <0> padav[@a:-437,-436] l
7  <@> sort lK
8  <0> pushmark s
9  <0> padav[@a:-437,-436] lRM*
a  <2> aassign[t2] KS/COMMON
b  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 427 optree_sort.t:172) v
# 2  <0> padav[@a:427,428] vM/LVINTRO
# 3  <;> nextstate(main 428 optree_sort.t:173) v
# 4  <0> pushmark s
# 5  <0> pushmark s
# 6  <0> padav[@a:427,428] l
# 7  <@> sort lK
# 8  <0> pushmark s
# 9  <0> padav[@a:427,428] lRM*
# a  <2> aassign[t2] KS/COMMON
# b  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> 'my @a; @a = sort @a',
	      prog	=> 'my @a; @a = sort @a',
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <0> enter 
2  <;> nextstate(main 1 -e:1) v:{
3  <0> padav[@a:1,2] vM/LVINTRO
4  <;> nextstate(main 2 -e:1) v:{
5  <0> pushmark s
6  <0> pushmark s
7  <0> padav[@a:1,2] lRM*
8  <@> sort lK/INPLACE
9  <@> leave[1 ref] vKP/REFC
EOT_EOT
# 1  <0> enter 
# 2  <;> nextstate(main 1 -e:1) v:{
# 3  <0> padav[@a:1,2] vM/LVINTRO
# 4  <;> nextstate(main 2 -e:1) v:{
# 5  <0> pushmark s
# 6  <0> pushmark s
# 7  <0> padav[@a:1,2] lRM*
# 8  <@> sort lK/INPLACE
# 9  <@> leave[1 ref] vKP/REFC
EONT_EONT

checkOptree ( name	=> 'sub {my @a; @a = sort @a; push @a, 1}',
	      code	=> sub {my @a; @a = sort @a; push @a, 1},
	      bcopts	=> '-exec',
	      debug	=> 0,
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <;> nextstate(main -437 optree.t:325) v
2  <0> padav[@a:-437,-436] vM/LVINTRO
3  <;> nextstate(main -436 optree.t:325) v
4  <0> pushmark s
5  <0> pushmark s
6  <0> padav[@a:-437,-436] lRM*
7  <@> sort lK/INPLACE
8  <;> nextstate(main -436 optree.t:325) v:{
9  <0> pushmark s
a  <0> padav[@a:-437,-436] lRM
b  <$> const[IV 1] s
c  <@> push[t3] sK/2
d  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 429 optree_sort.t:219) v
# 2  <0> padav[@a:429,430] vM/LVINTRO
# 3  <;> nextstate(main 430 optree_sort.t:220) v
# 4  <0> pushmark s
# 5  <0> pushmark s
# 6  <0> padav[@a:429,430] lRM*
# 7  <@> sort lK/INPLACE
# 8  <;> nextstate(main 430 optree_sort.t:220) v:{
# 9  <0> pushmark s
# a  <0> padav[@a:429,430] lRM
# b  <$> const(IV 1) s
# c  <@> push[t3] sK/2
# d  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> 'sub {my @a; @a = sort @a; 1}',
	      code	=> sub {my @a; @a = sort @a; 1},
	      bcopts	=> '-exec',
	      debug	=> 0,
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <;> nextstate(main -437 optree.t:325) v
2  <0> padav[@a:-437,-436] vM/LVINTRO
3  <;> nextstate(main -436 optree.t:325) v
4  <0> pushmark s
5  <0> pushmark s
6  <0> padav[@a:-437,-436] lRM*
7  <@> sort lK/INPLACE
8  <;> nextstate(main -436 optree.t:346) v:{
9  <$> const[IV 1] s
a  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 431 optree_sort.t:250) v
# 2  <0> padav[@a:431,432] vM/LVINTRO
# 3  <;> nextstate(main 432 optree_sort.t:251) v
# 4  <0> pushmark s
# 5  <0> pushmark s
# 6  <0> padav[@a:431,432] lRM*
# 7  <@> sort lK/INPLACE
# 8  <;> nextstate(main 432 optree_sort.t:251) v:{
# 9  <$> const(IV 1) s
# a  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

} #skip

__END__

