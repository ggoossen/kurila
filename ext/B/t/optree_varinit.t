#!perl

BEGIN {
    if (env::var('PERL_CORE')){
	push $^INCLUDE_PATH, '../ext/B/t';
    } else {
	unshift $^INCLUDE_PATH, 't';
	push $^INCLUDE_PATH, "../../t";
    }
    require Config;
    # require 'test.pl'; # now done by OptreeCheck
}
use OptreeCheck;
use Config;
plan tests	=> 13;
SKIP: do {
skip "no perlio in this build", 22 unless Config::config_value("useperlio");

pass("OPTIMIZER TESTS - VAR INITIALIZATION");

checkOptree ( name	=> 'sub {our $a}',
	      bcopts	=> '-exec',
	      code	=> sub {our $a},
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <;> nextstate(main 21 optree.t:47) v
2  <#> gvsv[*a] s/OURINTR
3  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 51 optree.t:56) v
# 2  <$> gvsv(*a) s/OURINTR
# 3  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> 'sub {local $a}',
	      bcopts	=> '-exec',
	      code	=> sub {local $a},
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <;> nextstate(main 23 optree.t:57) v:{
2  <#> gvsv[*a] sM/LVINTRO
3  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 53 optree.t:67) v:{
# 2  <$> gvsv(*a) sM/LVINTRO
# 3  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> 'my $a',
	      prog	=> 'my $a',
	      bcopts	=> '-basic',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 4  <@> leave[1 ref] vKP/REFC ->(end)
# 1     <0> enter ->2
# 2     <;> nextstate(main 1 -e:1) v:{ ->3
# 3     <0> padsv[$a:1,2] vM/LVINTRO ->4
EOT_EOT
# 4  <@> leave[1 ref] vKP/REFC ->(end)
# 1     <0> enter ->2
# 2     <;> nextstate(main 1 -e:1) v:{ ->3
# 3     <0> padsv[$a:1,2] vM/LVINTRO ->4
EONT_EONT

checkOptree ( name	=> 'our $a',
	      prog	=> 'our $a',
	      bcopts	=> '-basic',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
4  <@> leave[1 ref] vKP/REFC ->(end)
1     <0> enter ->2
2     <;> nextstate(main 1 -e:1) v:{ ->3
-     <1> ex-rv2sv vK/17 ->4
3        <#> gvsv[*a] s/OURINTR ->4
EOT_EOT
# 4  <@> leave[1 ref] vKP/REFC ->(end)
# 1     <0> enter ->2
# 2     <;> nextstate(main 1 -e:1) v:{ ->3
# -     <1> ex-rv2sv vK/17 ->4
# 3        <$> gvsv(*a) s/OURINTR ->4
EONT_EONT

checkOptree ( name	=> 'local $a',
	      prog	=> 'local $a',
	      errs      => \@('Name "main::a" used only once: possible typo at -e line 1.'),
	      bcopts	=> '-basic',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
4  <@> leave[1 ref] vKP/REFC ->(end)
1     <0> enter ->2
2     <;> nextstate(main 1 -e:1) v:{ ->3
-     <1> ex-rv2sv vKM/129 ->4
3        <#> gvsv[*a] sM/LVINTRO ->4
EOT_EOT
# 4  <@> leave[1 ref] vKP/REFC ->(end)
# 1     <0> enter ->2
# 2     <;> nextstate(main 1 -e:1) v:{ ->3
# -     <1> ex-rv2sv vKM/129 ->4
# 3        <$> gvsv(*a) sM/LVINTRO ->4
EONT_EONT

pass("MY, OUR, LOCAL, BOTH SUB AND MAIN, = undef");

checkOptree ( name	=> 'my $a=undef',
	      prog	=> 'my $a=undef',
	      bcopts	=> '-basic',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
6  <@> leave[1 ref] vKP/REFC ->(end)
1     <0> enter ->2
2     <;> nextstate(main 1 -e:1) v:{ ->3
5     <2> sassign vKS/2 ->6
3        <0> undef s ->4
4        <0> padsv[$a:1,2] vRM*/LVINTRO ->5
EOT_EOT
# 6  <@> leave[1 ref] vKP/REFC ->(end)
# 1     <0> enter ->2
# 2     <;> nextstate(main 1 -e:1) v:{ ->3
# 5     <2> sassign vKS/2 ->6
# 3        <0> undef s ->4
# 4        <0> padsv[$a:1,2] vRM*/LVINTRO ->5
EONT_EONT

checkOptree ( name	=> 'our $a=undef',
	      prog	=> 'our $a=undef',
	      note	=> 'global must be reassigned',
	      bcopts	=> '-basic',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
6  <@> leave[1 ref] vKP/REFC ->(end)
1     <0> enter ->2
2     <;> nextstate(main 1 -e:1) v:{ ->3
5     <2> sassign vKS/2 ->6
3        <0> undef s ->4
-        <1> ex-rv2sv vKRM*/17 ->5
4           <#> gvsv[*a] sM/OURINTR ->5
EOT_EOT
# 6  <@> leave[1 ref] vKP/REFC ->(end)
# 1     <0> enter ->2
# 2     <;> nextstate(main 1 -e:1) v:{ ->3
# 5     <2> sassign vKS/2 ->6
# 3        <0> undef s ->4
# -        <1> ex-rv2sv vKRM*/17 ->5
# 4           <$> gvsv(*a) sM/OURINTR ->5
EONT_EONT

checkOptree ( name	=> 'local $a=undef',
	      prog	=> 'local $a=undef',
	      errs      => \@('Name "main::a" used only once: possible typo at -e line 1.'),
	      note	=> 'locals are rare, probly not worth doing',
	      bcopts	=> '-basic',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
6  <@> leave[1 ref] vKP/REFC ->(end)
1     <0> enter ->2
2     <;> nextstate(main 1 -e:1) v:{ ->3
5     <2> sassign vKS/2 ->6
3        <0> undef s ->4
-        <1> ex-rv2sv vKRM*/129 ->5
4           <#> gvsv[*a] sM/LVINTRO ->5
EOT_EOT
# 6  <@> leave[1 ref] vKP/REFC ->(end)
# 1     <0> enter ->2
# 2     <;> nextstate(main 1 -e:1) v:{ ->3
# 5     <2> sassign vKS/2 ->6
# 3        <0> undef s ->4
# -        <1> ex-rv2sv vKRM*/129 ->5
# 4           <$> gvsv(*a) sM/LVINTRO ->5
EONT_EONT

checkOptree ( name	=> 'sub {my $a=()}',
	      code	=> sub {my $a=()},
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <;> nextstate(main -439 optree.t:105) v
2  <0> stub sP
3  <0> padsv[$a:-439,-438] sRM*/LVINTRO
4  <2> sassign sKS/2
5  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 438 optree_varinit.t:247) v
# 2  <0> stub sP
# 3  <0> padsv[$a:438,439] sRM*/LVINTRO
# 4  <2> sassign sKS/2
# 5  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> 'sub {our $a=()}',
	      code	=> sub {our $a=()},
              #todo	=> 'probly not worth doing',
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <;> nextstate(main 31 optree.t:177) v:{
2  <0> stub sP
3  <#> gvsv[*a] sM/OURINTR
4  <2> sassign sKS/2
5  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 440 optree_varinit.t:262) v:{
# 2  <0> stub sP
# 3  <$> gvsv(*a) sM/OURINTR
# 4  <2> sassign sKS/2
# 5  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> 'sub {local $a=()}',
	      code	=> sub {local $a=()},
              #todo	=> 'probly not worth doing',
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <;> nextstate(main 33 optree.t:190) v:{
2  <0> stub sP
3  <#> gvsv[*a] sM/LVINTRO
4  <2> sassign sKS/2
5  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 63 optree.t:225) v:{
# 2  <0> stub sP
# 3  <$> gvsv(*a) sM/LVINTRO
# 4  <2> sassign sKS/2
# 5  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

};

__END__

