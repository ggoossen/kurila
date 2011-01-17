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
plan tests => 18;


=head1 f_map.t

Code test snippets here are adapted from `perldoc -f map`

Due to a bleadperl optimization (Dave Mitchell, circa may 04), the
(map|grep)(start|while) opcodes have different flags in 5.9, their
private flags /1, /2 are gone in blead (for the cases covered)

When the optree stuff was integrated into 5.8.6, these tests failed,
and were todo'd.  They're now done, by version-specific tweaking in
mkCheckRex(), therefore the skip is removed too.

=for gentest

# chunk: #!perl
# examples shamelessly snatched from perldoc -f map

=cut

=for gentest

# chunk: # translates a list of numbers to the corresponding characters.
@chars = map(chr, @nums);

=cut

checkOptree(note   => q{},
	    bcopts => q{-postorder},
	    code   => q{@chars = map(chr, @nums); },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 701 (eval 12):1) v 
# 2  <#> gv[*_] s 
# 3  <1> rv2sv sK/1 
# 4  <1> chr[t5] sK/1 
# 5  <1> null lK/1 
# 6  <#> gv[*nums] s 
# 7  <1> rv2av[t7] lKM/1 
# 8  <@> mapstart[t8] lK 
# 9  <@> list lK 
# a  <#> gv[*chars] s 
# b  <1> rv2av[t2] lKRM*/1 
# c  <@> list lK 
# d  <2> aassign[t9] KS/COMMON 
# e  <@> lineseq KP 
# f  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 2  <$> gv(*_) s 
# 3  <1> rv2sv sK/1 
# 4  <1> chr[t3] sK/1 
# 5  <1> null lK/1 
# 6  <$> gv(*nums) s 
# 7  <1> rv2av[t4] lKM/1 
# 8  <@> mapstart[t5] lK 
# 9  <@> list lK 
# a  <$> gv(*chars) s 
# b  <1> rv2av[t1] lKRM*/1 
# c  <@> list lK 
# d  <2> aassign[t6] KS/COMMON 
# e  <@> lineseq KP 
# f  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT


=for gentest

# chunk: %hash = map { getkey($_) => $_ } @array;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{%hash = map { getkey($_) => $_ } @array; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 790 (eval 15):1) v:{ 
# 2  <0> enter l 
# 3  <;> nextstate(main 789 (eval 15):1) v:{ 
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
# f  <#> gv[*array] s 
# g  <1> rv2av[t9] lKM/1 
# h  <@> mapstart[t10] lK* 
# i  <@> list lK 
# j  <#> gv[*hash] s 
# k  <1> rv2hv[t2] lKRM*/1 
# l  <@> list lK 
# m  <2> aassign[t11] KS/COMMON 
# n  <@> lineseq KP 
# o  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 803 (eval 15):1) v:{ 
# 2  <0> enter l 
# 3  <;> nextstate(main 802 (eval 15):1) v:{ 
# 4  <$> gv(*_) s 
# 5  <1> rv2sv sKM/1 
# 6  <$> gv(*getkey) s/EARLYCV 
# 7  <1> ex-rv2cv sK 
# 8  <1> entersub[t2] lKS/TARG 
# 9  <$> gv(*_) s 
# a  <1> rv2sv sK/1 
# b  <@> list lK 
# c  <@> leave lKP 
# d  <1> null lK/1 
# e  <1> null lK/1 
# f  <$> gv(*array) s 
# g  <1> rv2av[t3] lKM/1 
# h  <@> mapstart[t4] lK* 
# i  <@> list lK 
# j  <$> gv(*hash) s 
# k  <1> rv2hv[t1] lKRM*/1 
# l  <@> list lK 
# m  <2> aassign[t5] KS/COMMON 
# n  <@> lineseq KP 
# o  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT


=for gentest

# chunk: {
    %hash = ();
    foreach $_ (@array) {
	$hash{getkey($_)} = $_;
    }
}

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{{ %hash = (); foreach $_ (@array) { $hash{getkey($_)} = $_; } } },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 478 (eval 10):1) v:{
# 2  <{> enterloop(next->u last->u redo->3) 
# 3  <;> nextstate(main 475 (eval 10):1) v
# 4  <0> pushmark s
# 5  <0> pushmark s
# 6  <#> gv[*hash] s
# 7  <1> rv2hv[t2] lKRM*/1
# 8  <2> aassign[t3] vKS
# 9  <;> nextstate(main 476 (eval 10):1) v:{
# a  <0> pushmark sM
# b  <#> gv[*array] s
# c  <1> rv2av[t6] sKRM/1
# d  <#> gv[*_] s
# e  <1> rv2gv sKRM/1
# f  <{> enteriter(next->q last->t redo->g) lKS/8
# r  <0> iter s
# s  <|> and(other->g) K/1
# g      <;> nextstate(main 475 (eval 10):1) v:{
# h      <#> gvsv[*_] s
# i      <#> gv[*hash] s
# j      <1> rv2hv sKR/1
# k      <0> pushmark s
# l      <#> gvsv[*_] s
# m      <#> gv[*getkey] s/EARLYCV
# n      <1> entersub[t10] sKS/TARG
# o      <2> helem sKRM*/2
# p      <2> sassign vKS/2
# q      <0> unstack s
#            goto r
# t  <2> leaveloop KP/2
# u  <2> leaveloop K/2
# v  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 562 (eval 15):1) v:{
# 2  <{> enterloop(next->u last->u redo->3) 
# 3  <;> nextstate(main 559 (eval 15):1) v
# 4  <0> pushmark s
# 5  <0> pushmark s
# 6  <$> gv(*hash) s
# 7  <1> rv2hv[t1] lKRM*/1
# 8  <2> aassign[t2] vKS
# 9  <;> nextstate(main 560 (eval 15):1) v:{
# a  <0> pushmark sM
# b  <$> gv(*array) s
# c  <1> rv2av[t3] sKRM/1
# d  <$> gv(*_) s
# e  <1> rv2gv sKRM/1
# f  <{> enteriter(next->q last->t redo->g) lKS/8
# r  <0> iter s
# s  <|> and(other->g) K/1
# g      <;> nextstate(main 559 (eval 15):1) v:{
# h      <$> gvsv(*_) s
# i      <$> gv(*hash) s
# j      <1> rv2hv sKR/1
# k      <0> pushmark s
# l      <$> gvsv(*_) s
# m      <$> gv(*getkey) s/EARLYCV
# n      <1> entersub[t4] sKS/TARG
# o      <2> helem sKRM*/2
# p      <2> sassign vKS/2
# q      <0> unstack s
#            goto r
# t  <2> leaveloop KP/2
# u  <2> leaveloop K/2
# v  <1> leavesub[1 ref] K/REFC,1
EONT_EONT


=for gentest

# chunk: #%hash = map {  "\L$_", 1  } @array;  # perl guesses EXPR.  wrong
%hash = map { +"\L$_", 1  } @array;  # perl guesses BLOCK. right

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{%hash = map { +"\L$_", 1 } @array; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 804 (eval 19):1) v 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*_] s 
# 4  <1> rv2sv sK/1 
# 5  <1> lc[t4] sK/1 
# 6  <@> stringify[t5] sK/1 
# 7  <$> const[IV 1] s 
# 8  <@> list lK 
# 9  <@> scope lK 
# a  <1> null lK/1 
# b  <1> null lK/1 
# c  <#> gv[*array] s 
# d  <1> rv2av[t7] lKM/1 
# e  <@> mapstart[t8] lK* 
# f  <@> list lK 
# g  <#> gv[*hash] s 
# h  <1> rv2hv[t2] lKRM*/1 
# i  <@> list lK 
# j  <2> aassign[t9] KS/COMMON 
# k  <@> lineseq KP 
# l  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 817 (eval 19):1) v 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*_) s 
# 4  <1> rv2sv sK/1 
# 5  <1> lc[t2] sK/1 
# 6  <@> stringify[t3] sK/1 
# 7  <$> const(IV 1) s 
# 8  <@> list lK 
# 9  <@> scope lK 
# a  <1> null lK/1 
# b  <1> null lK/1 
# c  <$> gv(*array) s 
# d  <1> rv2av[t4] lKM/1 
# e  <@> mapstart[t5] lK* 
# f  <@> list lK 
# g  <$> gv(*hash) s 
# h  <1> rv2hv[t1] lKRM*/1 
# i  <@> list lK 
# j  <2> aassign[t6] KS/COMMON 
# k  <@> lineseq KP 
# l  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT


=for gentest

# chunk: %hash = map { ("\L$_", 1) } @array;  # this also works

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{%hash = map { ("\L$_", 1) } @array; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 810 (eval 21):1) v 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*_] s 
# 4  <1> rv2sv sK/1 
# 5  <1> lc[t4] sK/1 
# 6  <@> stringify[t5] sK/1 
# 7  <$> const[IV 1] s 
# 8  <@> list lKP 
# 9  <@> scope lK 
# a  <1> null lK/1 
# b  <1> null lK/1 
# c  <#> gv[*array] s 
# d  <1> rv2av[t7] lKM/1 
# e  <@> mapstart[t8] lK* 
# f  <@> list lK 
# g  <#> gv[*hash] s 
# h  <1> rv2hv[t2] lKRM*/1 
# i  <@> list lK 
# j  <2> aassign[t9] KS/COMMON 
# k  <@> lineseq KP 
# l  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 823 (eval 21):1) v 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*_) s 
# 4  <1> rv2sv sK/1 
# 5  <1> lc[t2] sK/1 
# 6  <@> stringify[t3] sK/1 
# 7  <$> const(IV 1) s 
# 8  <@> list lKP 
# 9  <@> scope lK 
# a  <1> null lK/1 
# b  <1> null lK/1 
# c  <$> gv(*array) s 
# d  <1> rv2av[t4] lKM/1 
# e  <@> mapstart[t5] lK* 
# f  <@> list lK 
# g  <$> gv(*hash) s 
# h  <1> rv2hv[t1] lKRM*/1 
# i  <@> list lK 
# j  <2> aassign[t6] KS/COMMON 
# k  <@> lineseq KP 
# l  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT


=for gentest

# chunk: %hash = map {  lc($_), 1  } @array;  # as does this.

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{%hash = map { lc($_), 1 } @array; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 816 (eval 23):1) v 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*_] s 
# 4  <1> rv2sv sK/1 
# 5  <1> lc[t4] sK/1 
# 6  <$> const[IV 1] s 
# 7  <@> list lK 
# 8  <@> scope lK 
# 9  <1> null lK/1 
# a  <1> null lK/1 
# b  <#> gv[*array] s 
# c  <1> rv2av[t6] lKM/1 
# d  <@> mapstart[t7] lK* 
# e  <@> list lK 
# f  <#> gv[*hash] s 
# g  <1> rv2hv[t2] lKRM*/1 
# h  <@> list lK 
# i  <2> aassign[t8] KS/COMMON 
# j  <@> lineseq KP 
# k  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 829 (eval 23):1) v 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*_) s 
# 4  <1> rv2sv sK/1 
# 5  <1> lc[t2] sK/1 
# 6  <$> const(IV 1) s 
# 7  <@> list lK 
# 8  <@> scope lK 
# 9  <1> null lK/1 
# a  <1> null lK/1 
# b  <$> gv(*array) s 
# c  <1> rv2av[t3] lKM/1 
# d  <@> mapstart[t4] lK* 
# e  <@> list lK 
# f  <$> gv(*hash) s 
# g  <1> rv2hv[t1] lKRM*/1 
# h  <@> list lK 
# i  <2> aassign[t5] KS/COMMON 
# j  <@> lineseq KP 
# k  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT


=for gentest

# chunk: %hash = map +( lc($_), 1 ), @array;  # this is EXPR and works!

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{%hash = map +( lc($_), 1 ), @array; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 821 (eval 25):1) v 
# 2  <#> gv[*_] s 
# 3  <1> rv2sv sK/1 
# 4  <1> lc[t4] sK/1 
# 5  <$> const[IV 1] s 
# 6  <@> list lKP 
# 7  <1> null lK/1 
# 8  <#> gv[*array] s 
# 9  <1> rv2av[t6] lKM/1 
# a  <@> mapstart[t7] lK 
# b  <@> list lK 
# c  <#> gv[*hash] s 
# d  <1> rv2hv[t2] lKRM*/1 
# e  <@> list lK 
# f  <2> aassign[t8] KS/COMMON 
# g  <@> lineseq KP 
# h  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 834 (eval 25):1) v 
# 2  <$> gv(*_) s 
# 3  <1> rv2sv sK/1 
# 4  <1> lc[t2] sK/1 
# 5  <$> const(IV 1) s 
# 6  <@> list lKP 
# 7  <1> null lK/1 
# 8  <$> gv(*array) s 
# 9  <1> rv2av[t3] lKM/1 
# a  <@> mapstart[t4] lK 
# b  <@> list lK 
# c  <$> gv(*hash) s 
# d  <1> rv2hv[t1] lKRM*/1 
# e  <@> list lK 
# f  <2> aassign[t5] KS/COMMON 
# g  <@> lineseq KP 
# h  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT


=for gentest

# chunk: %hash = map  ( lc($_), 1 ), @array;  # evaluates to (1, @array)

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{%hash = map ( lc($_), 1 ), @array; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 826 (eval 27):1) v 
# 2  <#> gv[*_] s 
# 3  <1> rv2sv sK/1 
# 4  <1> lc[t4] sK/1 
# 5  <1> null lK/1 
# 6  <$> const[IV 1] sM 
# 7  <@> mapstart[t5] lK 
# 8  <@> list lK 
# 9  <#> gv[*hash] s 
# a  <1> rv2hv[t2] lKRM*/1 
# b  <@> list lK 
# c  <2> aassign[t6] KS/COMMON 
# d  <#> gv[*array] s 
# e  <1> rv2av[t8] K/1 
# f  <@> list K 
# g  <@> lineseq KP 
# h  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 839 (eval 27):1) v 
# 2  <$> gv(*_) s 
# 3  <1> rv2sv sK/1 
# 4  <1> lc[t2] sK/1 
# 5  <1> null lK/1 
# 6  <$> const(IV 1) sM 
# 7  <@> mapstart[t3] lK 
# 8  <@> list lK 
# 9  <$> gv(*hash) s 
# a  <1> rv2hv[t1] lKRM*/1 
# b  <@> list lK 
# c  <2> aassign[t4] KS/COMMON 
# d  <$> gv(*array) s 
# e  <1> rv2av[t5] K/1 
# f  <@> list K 
# g  <@> lineseq KP 
# h  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT


=for gentest

# chunk: @hashes = map +{ lc($_), 1 }, @array # EXPR, so needs , at end

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{@hashes = map +{ lc($_), 1 }, @array },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 831 (eval 29):1) v 
# 2  <#> gv[*_] s 
# 3  <1> rv2sv sK/1 
# 4  <1> lc[t4] sK/1 
# 5  <$> const[IV 1] s 
# 6  <@> anonhash sK*/1 
# 7  <1> null lK/1 
# 8  <#> gv[*array] s 
# 9  <1> rv2av[t6] lKM/1 
# a  <@> mapstart[t7] lK 
# b  <@> list lK 
# c  <#> gv[*hashes] s 
# d  <1> rv2av[t2] lKRM*/1 
# e  <@> list lK 
# f  <2> aassign[t8] KS/COMMON 
# g  <@> lineseq KP 
# h  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 844 (eval 29):1) v 
# 2  <$> gv(*_) s 
# 3  <1> rv2sv sK/1 
# 4  <1> lc[t2] sK/1 
# 5  <$> const(IV 1) s 
# 6  <@> anonhash sK*/1 
# 7  <1> null lK/1 
# 8  <$> gv(*array) s 
# 9  <1> rv2av[t3] lKM/1 
# a  <@> mapstart[t4] lK 
# b  <@> list lK 
# c  <$> gv(*hashes) s 
# d  <1> rv2av[t1] lKRM*/1 
# e  <@> list lK 
# f  <2> aassign[t5] KS/COMMON 
# g  <@> lineseq KP 
# h  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
