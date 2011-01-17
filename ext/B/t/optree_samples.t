#!perl

BEGIN {
    unshift @INC, 't';
    require Config;
    if (($Config::Config{'extensions'} !~ /\bB\b/) ){
        print "1..0 # Skip -- Perl configured without B module\n";
        exit 0;
    }
    if (!$Config::Config{useperlio}) {
        print "1..0 # Skip -- need perlio to walk the optree\n";
        exit 0;
    }
}
use OptreeCheck;
use Config;
skip_all("test not for new codegen") if $^V == v5.14;
plan tests	=> 34;

pass("GENERAL OPTREE EXAMPLES");

pass("IF,THEN,ELSE, ?:");

checkOptree ( name	=> '-basic sub {if shift print then,else}',
	      bcopts	=> '-basic',
	      code	=> sub { if (shift) { print "then" }
				 else       { print "else" }
			     },
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# e  <1> leavesub[1 ref] K/REFC,1 
# d     <@> lineseq KP 
# 1        <;> nextstate(main 704 optree_samples.t:24) v 
# c        <|> cond_expr(other->?) K/1 
# 2           <0> shift s* 
# 6           <@> scope K 
# 3              <0> ex-nextstate v 
# 5              <@> print sK 
# 4                 <$> const[PV "then"] s 
# b           <@> leave KP 
# 7              <0> enter 
# 8              <;> nextstate(main 702 optree_samples.t:25) v 
# a              <@> print sK 
# 9                 <$> const[PV "else"] s 
EOT_EOT
# 7  <1> leavesub[1 ref] K/REFC,1 ->(end)
# -     <@> lineseq KP ->7
# 1        <;> nextstate(main 665 optree_samples.t:24) v:>,<,% ->2
# -        <1> null K/1 ->-
# 3           <|> cond_expr(other->4) K/1 ->8
# 2              <0> shift s* ->3
# -              <@> scope K ->-
# -                 <0> ex-nextstate v ->4
# 6                 <@> print sK ->7
# 4                    <0> pushmark s ->5
# 5                    <$> const(PV "then") s ->6
# d              <@> leave KP ->7
# 8                 <0> enter ->9
# 9                 <;> nextstate(main 663 optree_samples.t:25) v:>,<,% ->a
# c                 <@> print sK ->d
# a                    <0> pushmark s ->b
# b                    <$> const(PV "else") s ->c
EONT_EONT

checkOptree ( name	=> '-basic (see above, with my $a = shift)',
	      bcopts	=> '-basic',
	      code	=> sub { my $a = shift;
				 if ($a) { print "foo" }
				 else    { print "bar" }
			     },
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# i  <1> leavesub[1 ref] K/REFC,1 
# h     <@> lineseq KP 
# 1        <;> nextstate(main 705 optree_samples.t:68) v 
# 4        <2> sassign vKS/2 
# 2           <0> shift s* 
# 3           <0> padsv[$a:705,709] sRM*/LVINTRO 
# 5        <;> nextstate(main 709 optree_samples.t:69) v 
# g        <|> cond_expr(other->?) K/1 
# 6           <0> padsv[$a:705,709] s 
# a           <@> scope K 
# 7              <0> ex-nextstate v 
# 9              <@> print sK 
# 8                 <$> const[PV "foo"] s 
# f           <@> leave KP 
# b              <0> enter 
# c              <;> nextstate(main 707 optree_samples.t:70) v 
# e              <@> print sK 
# d                 <$> const[PV "bar"] s 
EOT_EOT
# b  <1> leavesub[1 ref] K/REFC,1 ->(end)
# -     <@> lineseq KP ->b
# 1        <;> nextstate(main 666 optree_samples.t:72) v:>,<,% ->2
# 4        <2> sassign vKS/2 ->5
# 2           <0> shift s* ->3
# 3           <0> padsv[$a:666,670] sRM*/LVINTRO ->4
# 5        <;> nextstate(main 670 optree_samples.t:73) v:>,<,% ->6
# -        <1> null K/1 ->-
# 7           <|> cond_expr(other->8) K/1 ->c
# 6              <0> padsv[$a:666,670] s ->7
# -              <@> scope K ->-
# -                 <0> ex-nextstate v ->8
# a                 <@> print sK ->b
# 8                    <0> pushmark s ->9
# 9                    <$> const(PV "foo") s ->a
# h              <@> leave KP ->b
# c                 <0> enter ->d
# d                 <;> nextstate(main 668 optree_samples.t:74) v:>,<,% ->e
# g                 <@> print sK ->h
# e                    <0> pushmark s ->f
# f                    <$> const(PV "bar") s ->g
EONT_EONT

checkOptree ( name	=> '-exec sub {if shift print then,else}',
	      bcopts	=> '-exec',
	      code	=> sub { if (shift) { print "then" }
				 else       { print "else" }
			     },
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 713 optree_samples.t:121) v 
# 2  <0> shift s* 
# 3  <0> ex-nextstate v 
# 4  <$> const[PV "then"] s 
# 5  <@> print sK 
# 6  <@> scope K 
# 7  <0> enter 
# 8  <;> nextstate(main 711 optree_samples.t:122) v 
# 9  <$> const[PV "else"] s 
# a  <@> print sK 
# b  <@> leave KP 
# c  <|> cond_expr(other->?) K/1 
# d  <@> lineseq KP 
# e  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 674 optree_samples.t:129) v:>,<,%
# 2  <0> shift s*
# 3  <|> cond_expr(other->4) K/1
# 4      <0> pushmark s
# 5      <$> const(PV "then") s
# 6      <@> print sK
#            goto 7
# 8  <0> enter 
# 9  <;> nextstate(main 672 optree_samples.t:130) v:>,<,%
# a  <0> pushmark s
# b  <$> const(PV "else") s
# c  <@> print sK
# d  <@> leave KP
# 7  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> '-exec (see above, with my $a = shift)',
	      bcopts	=> '-exec',
	      code	=> sub { my $a = shift;
				 if ($a) { print "foo" }
				 else    { print "bar" }
			     },
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 714 optree_samples.t:159) v 
# 2  <0> shift s* 
# 3  <0> padsv[$a:714,718] sRM*/LVINTRO 
# 4  <2> sassign vKS/2 
# 5  <;> nextstate(main 718 optree_samples.t:160) v 
# 6  <0> padsv[$a:714,718] s 
# 7  <0> ex-nextstate v 
# 8  <$> const[PV "foo"] s 
# 9  <@> print sK 
# a  <@> scope K 
# b  <0> enter 
# c  <;> nextstate(main 716 optree_samples.t:161) v 
# d  <$> const[PV "bar"] s 
# e  <@> print sK 
# f  <@> leave KP 
# g  <|> cond_expr(other->?) K/1 
# h  <@> lineseq KP 
# i  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 675 optree_samples.t:171) v:>,<,%
# 2  <0> shift s*
# 3  <0> padsv[$a:675,679] sRM*/LVINTRO
# 4  <2> sassign vKS/2
# 5  <;> nextstate(main 679 optree_samples.t:172) v:>,<,%
# 6  <0> padsv[$a:675,679] s
# 7  <|> cond_expr(other->8) K/1
# 8      <0> pushmark s
# 9      <$> const(PV "foo") s
# a      <@> print sK
#            goto b
# c  <0> enter 
# d  <;> nextstate(main 677 optree_samples.t:173) v:>,<,%
# e  <0> pushmark s
# f  <$> const(PV "bar") s
# g  <@> print sK
# h  <@> leave KP
# b  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> '-exec sub { print (shift) ? "foo" : "bar" }',
	      code	=> sub { print (shift) ? "foo" : "bar" },
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 719 optree_samples.t:205) v 
# 2  <0> shift s* 
# 3  <@> print sK 
# 4  <$> const[PV "foo"] s 
# 5  <$> const[PV "bar"] s 
# 6  <|> cond_expr(other->?) K/1 
# 7  <@> lineseq KP 
# 8  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 680 optree_samples.t:221) v:>,<,%
# 2  <0> pushmark s
# 3  <0> shift s*
# 4  <@> print sK
# 5  <|> cond_expr(other->6) K/1
# 6      <$> const(PV "foo") s
#            goto 7
# 8  <$> const(PV "bar") s
# 7  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

pass ("FOREACH");

checkOptree ( name	=> '-exec sub { foreach (1..10) {print "foo $_"} }',
	      code	=> sub { foreach (1..10) {print "foo $_"} },
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 721 optree_samples.t:233) v 
# 2  <$> const[IV 1] s 
# 3  <$> const[IV 10] s 
# 4  <1> flip[t2] sK/LINENUM 
# 5  <|> range(other->?)[t1] lK/64 
# 6  <#> gv[*_] s 
# 7  <;> nextstate(main 720 optree_samples.t:233) v 
# 8  <$> const[PV "foo "] s 
# 9  <#> gv[*_] s 
# a  <1> rv2sv sK/1 
# b  <2> concat[t4] sK/2 
# c  <@> stringify[t5] sK/1 
# d  <@> print sK 
# e  <@> lineseq K 
# f  <{> foreach(next->? last->? redo->?) KS/8 
# g  <@> lineseq KP 
# h  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 444 optree_samples.t:182) v:>,<,%
# 2  <0> pushmark s
# 3  <$> const(IV 1) s
# 4  <$> const(IV 10) s
# 5  <$> gv(*_) s
# 6  <{> enteriter(next->d last->g redo->7) lKS/8
# e  <0> iter s
# f  <|> and(other->7) K/1
# 7      <;> nextstate(main 443 optree_samples.t:182) v:>,<,%
# 8      <0> pushmark s
# 9      <$> const(PV "foo ") s
# a      <$> gvsv(*_) s
# b      <2> concat[t3] sK/2
# c      <@> print vK
# d      <0> unstack s
#            goto e
# g  <2> leaveloop K/2
# h  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> '-basic sub { print "foo $_" foreach (1..10) }',
	      code	=> sub { print "foo $_" foreach (1..10) }, 
	      bcopts	=> '-basic',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# g  <1> leavesub[1 ref] K/REFC,1 
# f     <@> lineseq KP 
# 1        <;> nextstate(main 723 optree_samples.t:277) v 
# 2        <;> nextstate(main 723 optree_samples.t:277) v 
# e        <{> foreach(next->? last->? redo->?) KS/8 
# 6           <|> range(other->?)[t4] lKP/64 
# 5              <1> flip[t5] sK/LINENUM 
# 3                 <$> const[IV 1] s 
# 4                 <$> const[IV 10] s 
# 7           <#> gv[*_] s 
# d           <@> print sK 
# c              <@> stringify[t3] sK/1 
# b                 <2> concat[t2] sK/2 
# 8                    <$> const[PV "foo "] s 
# a                    <1> rv2sv sK/1 
# 9                       <#> gv[*_] s 
EOT_EOT
# g  <1> leavesub[1 ref] K/REFC,1 ->(end)
# -     <@> lineseq KP ->g
# 1        <;> nextstate(main 446 optree_samples.t:192) v:>,<,% ->2
# f        <2> leaveloop K/2 ->g
# 6           <{> enteriter(next->c last->f redo->7) lKS/8 ->d
# -              <0> ex-pushmark s ->2
# -              <1> ex-list lK ->5
# 2                 <0> pushmark s ->3
# 3                 <$> const(IV 1) s ->4
# 4                 <$> const(IV 10) s ->5
# 5              <$> gv(*_) s ->6
# -           <1> null K/1 ->f
# e              <|> and(other->7) K/1 ->f
# d                 <0> iter s ->e
# -                 <@> lineseq sK ->-
# b                    <@> print vK ->c
# 7                       <0> pushmark s ->8
# -                       <1> ex-stringify sK/1 ->b
# -                          <0> ex-pushmark s ->8
# a                          <2> concat[t1] sK/2 ->b
# 8                             <$> const(PV "foo ") s ->9
# -                             <1> ex-rv2sv sK/1 ->a
# 9                                <$> gvsv(*_) s ->a
# c                    <0> unstack s ->d
EONT_EONT

checkOptree ( name	=> '-exec -e foreach (1..10) {print qq{foo $_}}',
	      prog	=> 'foreach (1..10) {print qq{foo $_}}',
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <0> enter 
# 2  <;> nextstate(main 2 -e:1) v 
# 3  <$> const[IV 1] s 
# 4  <$> const[IV 10] s 
# 5  <1> flip[t2] sK/LINENUM 
# 6  <|> range(other->?)[t1] lK/64 
# 7  <#> gv[*_] s 
# 8  <;> nextstate(main 1 -e:1) v 
# 9  <$> const[PV "foo "] s 
# a  <#> gv[*_] s 
# b  <1> rv2sv sK/1 
# c  <2> concat[t4] sK/2 
# d  <@> stringify[t5] sK/1 
# e  <@> print vK 
# f  <@> lineseq vK 
# g  <{> foreach(next->? last->? redo->?) vKS/8 
# h  <@> leave[1 ref] vKP/REFC 
EOT_EOT
# 1  <0> enter 
# 2  <;> nextstate(main 2 -e:1) v:>,<,%,{
# 3  <0> pushmark s
# 4  <$> const(IV 1) s
# 5  <$> const(IV 10) s
# 6  <$> gv(*_) s
# 7  <{> enteriter(next->e last->h redo->8) lKS/8
# f  <0> iter s
# g  <|> and(other->8) vK/1
# 8      <;> nextstate(main 1 -e:1) v:>,<,%
# 9      <0> pushmark s
# a      <$> const(PV "foo ") s
# b      <$> gvsv(*_) s
# c      <2> concat[t3] sK/2
# d      <@> print vK
# e      <0> unstack v
#            goto f
# h  <2> leaveloop vK/2
# i  <@> leave[1 ref] vKP/REFC
EONT_EONT

checkOptree ( name	=> '-exec sub { print "foo $_" foreach (1..10) }',
	      code	=> sub { print "foo $_" foreach (1..10) }, 
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 724 optree_samples.t:381) v 
# 2  <;> nextstate(main 724 optree_samples.t:381) v 
# 3  <$> const[IV 1] s 
# 4  <$> const[IV 10] s 
# 5  <1> flip[t5] sK/LINENUM 
# 6  <|> range(other->?)[t4] lKP/64 
# 7  <#> gv[*_] s 
# 8  <$> const[PV "foo "] s 
# 9  <#> gv[*_] s 
# a  <1> rv2sv sK/1 
# b  <2> concat[t2] sK/2 
# c  <@> stringify[t3] sK/1 
# d  <@> print sK 
# e  <{> foreach(next->? last->? redo->?) KS/8 
# f  <@> lineseq KP 
# g  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 447 optree_samples.t:252) v:>,<,%
# 2  <0> pushmark s
# 3  <$> const(IV 1) s
# 4  <$> const(IV 10) s
# 5  <$> gv(*_) s
# 6  <{> enteriter(next->c last->f redo->7) lKS/8
# d  <0> iter s
# e  <|> and(other->7) K/1
# 7      <0> pushmark s
# 8      <$> const(PV "foo ") s
# 9      <$> gvsv(*_) s
# a      <2> concat[t1] sK/2
# b      <@> print vK
# c      <0> unstack s
#            goto d
# f  <2> leaveloop K/2
# g  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

pass("GREP: SAMPLES FROM PERLDOC -F GREP");

checkOptree ( name	=> '@foo = grep(!/^\#/, @bar)',
	      code	=> '@foo = grep(!/^\#/, @bar)',
	      bcopts	=> '-exec',
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 829 (eval 23):1) v:{ 
# 2  </> match(/"^\\#"/) s/RTIME 
# 3  <1> not sK/1 
# 4  <1> null lK/1 
# 5  <#> gv[*bar] s 
# 6  <1> rv2av[t4] lKM/1 
# 7  <@> grepstart[t5] lK 
# 8  <@> list lK 
# 9  <#> gv[*foo] s 
# a  <1> rv2av[t2] lKRM*/1 
# b  <@> list lK 
# c  <2> aassign[t6] KS/COMMON 
# d  <@> lineseq KP 
# e  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 496 (eval 20):1) v:{
# 2  <0> pushmark s
# 3  <0> pushmark s
# 4  <$> gv(*bar) s
# 5  <1> rv2av[t2] lKM/1
# 6  <@> grepstart lK
# 7  <|> grepwhile(other->8)[t3] lK
# 8      </> match(/"^\\#"/) s/RTIME
# 9      <1> not sK/1
#            goto 7
# a  <0> pushmark s
# b  <$> gv(*foo) s
# c  <1> rv2av[t1] lKRM*/1
# d  <2> aassign[t4] KS/COMMON
# e  <1> leavesub[1 ref] K/REFC,1
EONT_EONT


pass("MAP: SAMPLES FROM PERLDOC -F MAP");

checkOptree ( name	=> '%h = map { getkey($_) => $_ } @a',
	      code	=> '%h = map { getkey($_) => $_ } @a',
	      bcopts	=> '-exec',
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 835 (eval 25):1) v:{ 
# 2  <0> enter l 
# 3  <;> nextstate(main 834 (eval 25):1) v:{ 
# 4  <#> gv[*_] s 
# 5  <1> rv2sv sKM/1 
# 6  <#> gv[*getkey] s/EARLYCV 
# 7  <1> ex-rv2cv sK 
# 8  <1> entersub[t6] lKS/TARG 
# 9  <#> gv[*_] s 
# a  <1> rv2sv sK/1 
# b  <@> list lK 
# c  <@> leave lKP 
# d  <1> null lK/1 
# e  <1> null lK/1 
# f  <#> gv[*a] s 
# g  <1> rv2av[t9] lKM/1 
# h  <@> mapstart[t10] lK* 
# i  <@> list lK 
# j  <#> gv[*h] s 
# k  <1> rv2hv[t2] lKRM*/1 
# l  <@> list lK 
# m  <2> aassign[t11] KS/COMMON 
# n  <@> lineseq KP 
# o  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 501 (eval 22):1) v:{
# 2  <0> pushmark s
# 3  <0> pushmark s
# 4  <$> gv(*a) s
# 5  <1> rv2av[t3] lKM/1
# 6  <@> mapstart lK*
# 7  <|> mapwhile(other->8)[t4] lK
# 8      <0> enter l
# 9      <;> nextstate(main 500 (eval 22):1) v:{
# a      <0> pushmark s
# b      <0> pushmark s
# c      <$> gvsv(*_) s
# d      <$> gv(*getkey) s/EARLYCV
# e      <1> entersub[t2] lKS/TARG
# f      <$> gvsv(*_) s
# g      <@> list lK
# h      <@> leave lKP
#            goto 7
# i  <0> pushmark s
# j  <$> gv(*h) s
# k  <1> rv2hv[t1] lKRM*/1
# l  <2> aassign[t5] KS/COMMON
# m  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> '%h=(); for $_(@a){$h{getkey($_)} = $_}',
	      code	=> '%h=(); for $_(@a){$h{getkey($_)} = $_}',
	      bcopts	=> '-exec',
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 505 (eval 24):1) v
# 2  <0> pushmark s
# 3  <0> pushmark s
# 4  <#> gv[*h] s
# 5  <1> rv2hv[t2] lKRM*/1
# 6  <2> aassign[t3] vKS
# 7  <;> nextstate(main 506 (eval 24):1) v:{
# 8  <0> pushmark sM
# 9  <#> gv[*a] s
# a  <1> rv2av[t6] sKRM/1
# b  <#> gv[*_] s
# c  <1> rv2gv sKRM/1
# d  <{> enteriter(next->o last->r redo->e) lKS/8
# p  <0> iter s
# q  <|> and(other->e) K/1
# e      <;> nextstate(main 505 (eval 24):1) v:{
# f      <#> gvsv[*_] s
# g      <#> gv[*h] s
# h      <1> rv2hv sKR/1
# i      <0> pushmark s
# j      <#> gvsv[*_] s
# k      <#> gv[*getkey] s/EARLYCV
# l      <1> entersub[t10] sKS/TARG
# m      <2> helem sKRM*/2
# n      <2> sassign vKS/2
# o      <0> unstack s
#            goto p
# r  <2> leaveloop KP/2
# s  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 505 (eval 24):1) v
# 2  <0> pushmark s
# 3  <0> pushmark s
# 4  <$> gv(*h) s
# 5  <1> rv2hv[t1] lKRM*/1
# 6  <2> aassign[t2] vKS
# 7  <;> nextstate(main 506 (eval 24):1) v:{
# 8  <0> pushmark sM
# 9  <$> gv(*a) s
# a  <1> rv2av[t3] sKRM/1
# b  <$> gv(*_) s
# c  <1> rv2gv sKRM/1
# d  <{> enteriter(next->o last->r redo->e) lKS/8
# p  <0> iter s
# q  <|> and(other->e) K/1
# e      <;> nextstate(main 505 (eval 24):1) v:{
# f      <$> gvsv(*_) s
# g      <$> gv(*h) s
# h      <1> rv2hv sKR/1
# i      <0> pushmark s
# j      <$> gvsv(*_) s
# k      <$> gv(*getkey) s/EARLYCV
# l      <1> entersub[t4] sKS/TARG
# m      <2> helem sKRM*/2
# n      <2> sassign vKS/2
# o      <0> unstack s
#            goto p
# r  <2> leaveloop KP/2
# s  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> 'map $_+42, 10..20',
	      code	=> 'map $_+42, 10..20',
	      bcopts	=> '-exec',
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 847 (eval 29):1) v 
# 2  <#> gv[*_] s 
# 3  <1> rv2sv sK/1 
# 4  <$> const[IV 42] s 
# 5  <2> add[t2] sK/2 
# 6  <1> null lK/1 
# 7  <$> const[IV 10] s 
# 8  <$> const[IV 20] s 
# 9  <1> flip[t4] sK/LINENUM 
# a  <|> range(other->?)[t3] lKM/64 
# b  <@> mapstart[t5] K 
# c  <@> lineseq KP 
# d  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 511 (eval 26):1) v
# 2  <0> pushmark s
# 3  <$> const(AV ) s
# 4  <1> rv2av lKPM/1
# 5  <@> mapstart K
# 6  <|> mapwhile(other->7)[t4] K
# 7      <$> gvsv(*_) s
# 8      <$> const(IV 42) s
# 9      <2> add[t1] sK/2
#            goto 6
# a  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

pass("CONSTANTS");

checkOptree ( name	=> '-e use constant j => qq{junk}; print j',
	      prog	=> 'use constant j => qq{junk}; print j',
	      bcopts	=> '-exec',
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <0> enter 
# 2  <;> nextstate(main 71 -e:1) v:>,<,%,{
# 3  <0> pushmark s
# 4  <$> const[PV "junk"] s*
# 5  <@> print vK
# 6  <@> leave[1 ref] vKP/REFC
EOT_EOT
# 1  <0> enter 
# 2  <;> nextstate(main 71 -e:1) v:>,<,%,{
# 3  <0> pushmark s
# 4  <$> const(PV "junk") s*
# 5  <@> print vK
# 6  <@> leave[1 ref] vKP/REFC
EONT_EONT

__END__

#######################################################################

checkOptree ( name	=> '-exec sub a { print (shift) ? "foo" : "bar" }',
	      code	=> sub { print (shift) ? "foo" : "bar" },
	      bcopts	=> '-exec',
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
   insert threaded reference here
EOT_EOT
   insert non-threaded reference here
EONT_EONT

