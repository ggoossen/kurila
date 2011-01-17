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
plan tests => 40;

=head1 f_sort.t

Code test snippets here are adapted from `perldoc -f map`

Due to a bleadperl optimization (Dave Mitchell, circa apr 04), the
(map|grep)(start|while) opcodes have different flags in 5.9, their
private flags /1, /2 are gone in blead (for the cases covered)

When the optree stuff was integrated into 5.8.6, these tests failed,
and were todo'd.  They're now done, by version-specific tweaking in
mkCheckRex(), therefore the skip is removed too.

=head1 Test Notes

# chunk: #!perl
#examples poached from perldoc -f sort

NOTE: name is no longer a required arg for checkOptree, as label is
synthesized out of others.  HOWEVER, if the test-code has newlines in
it, the label must be overridden by an explicit name.

This is because t/TEST is quite particular about the test output it
processes, and multi-line labels violate its 1-line-per-test
expectations.

=for gentest

# chunk: # sort lexically
@articles = sort @files;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{@articles = sort @files; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 704 (eval 12):1) v 
# 2  <#> gv[*files] s 
# 3  <1> rv2av[t4] lK/1 
# 4  <@> sort lK 
# 5  <@> list lK 
# 6  <#> gv[*articles] s 
# 7  <1> rv2av[t2] lKRM*/1 
# 8  <@> list lK 
# 9  <2> aassign[t5] KS/COMMON 
# a  <@> lineseq KP 
# b  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 719 (eval 12):1) v 
# 2  <$> gv(*files) s 
# 3  <1> rv2av[t2] lK/1 
# 4  <@> sort lK 
# 5  <@> list lK 
# 6  <$> gv(*articles) s 
# 7  <1> rv2av[t1] lKRM*/1 
# 8  <@> list lK 
# 9  <2> aassign[t3] KS/COMMON 
# a  <@> lineseq KP 
# b  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # same thing, but with explicit sort routine
@articles = sort {$a cmp $b} @files;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{@articles = sort {$a cmp $b} @files; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 793 (eval 15):1) v 
# 2  <#> gv[*files] s 
# 3  <1> rv2av[t7] lK/1 
# 4  <@> sort lK 
# 5  <@> list lK 
# 6  <#> gv[*articles] s 
# 7  <1> rv2av[t2] lKRM*/1 
# 8  <@> list lK 
# 9  <2> aassign[t3] KS/COMMON 
# a  <@> lineseq KP 
# b  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 811 (eval 15):1) v 
# 2  <$> gv(*files) s 
# 3  <1> rv2av[t3] lK/1 
# 4  <@> sort lK 
# 5  <@> list lK 
# 6  <$> gv(*articles) s 
# 7  <1> rv2av[t1] lKRM*/1 
# 8  <@> list lK 
# 9  <2> aassign[t2] KS/COMMON 
# a  <@> lineseq KP 
# b  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # now case-insensitively
@articles = sort {uc($a) cmp uc($b)} @files;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{@articles = sort {uc($a) cmp uc($b)} @files; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 799 (eval 17):1) v 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*a] s 
# 4  <1> rv2sv sK/1 
# 5  <1> uc[t4] sK/1 
# 6  <#> gv[*b] s 
# 7  <1> rv2sv sK/1 
# 8  <1> uc[t6] sK/1 
# 9  <2> scmp[t7] sK/2 
# a  <@> scope sK 
# b  <1> null sK/1 
# c  <#> gv[*files] s 
# d  <1> rv2av[t9] lK/1 
# e  <@> sort lKS* 
# f  <@> list lK 
# g  <#> gv[*articles] s 
# h  <1> rv2av[t2] lKRM*/1 
# i  <@> list lK 
# j  <2> aassign[t10] KS/COMMON 
# k  <@> lineseq KP 
# l  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 817 (eval 17):1) v 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*a) s 
# 4  <1> rv2sv sK/1 
# 5  <1> uc[t2] sK/1 
# 6  <$> gv(*b) s 
# 7  <1> rv2sv sK/1 
# 8  <1> uc[t3] sK/1 
# 9  <2> scmp[t4] sK/2 
# a  <@> scope sK 
# b  <1> null sK/1 
# c  <$> gv(*files) s 
# d  <1> rv2av[t5] lK/1 
# e  <@> sort lKS* 
# f  <@> list lK 
# g  <$> gv(*articles) s 
# h  <1> rv2av[t1] lKRM*/1 
# i  <@> list lK 
# j  <2> aassign[t6] KS/COMMON 
# k  <@> lineseq KP 
# l  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # same thing in reversed order
@articles = sort {$b cmp $a} @files;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{@articles = sort {$b cmp $a} @files; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 805 (eval 19):1) v 
# 2  <#> gv[*files] s 
# 3  <1> rv2av[t7] lK/1 
# 4  <@> sort lK/DESC 
# 5  <@> list lK 
# 6  <#> gv[*articles] s 
# 7  <1> rv2av[t2] lKRM*/1 
# 8  <@> list lK 
# 9  <2> aassign[t3] KS/COMMON 
# a  <@> lineseq KP 
# b  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 823 (eval 19):1) v 
# 2  <$> gv(*files) s 
# 3  <1> rv2av[t3] lK/1 
# 4  <@> sort lK/DESC 
# 5  <@> list lK 
# 6  <$> gv(*articles) s 
# 7  <1> rv2av[t1] lKRM*/1 
# 8  <@> list lK 
# 9  <2> aassign[t2] KS/COMMON 
# a  <@> lineseq KP 
# b  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # sort numerically ascending
@articles = sort {$a <=> $b} @files;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{@articles = sort {$a <=> $b} @files; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 811 (eval 21):1) v 
# 2  <#> gv[*files] s 
# 3  <1> rv2av[t7] lK/1 
# 4  <@> sort lK/NUM 
# 5  <@> list lK 
# 6  <#> gv[*articles] s 
# 7  <1> rv2av[t2] lKRM*/1 
# 8  <@> list lK 
# 9  <2> aassign[t3] KS/COMMON 
# a  <@> lineseq KP 
# b  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 829 (eval 21):1) v 
# 2  <$> gv(*files) s 
# 3  <1> rv2av[t3] lK/1 
# 4  <@> sort lK/NUM 
# 5  <@> list lK 
# 6  <$> gv(*articles) s 
# 7  <1> rv2av[t1] lKRM*/1 
# 8  <@> list lK 
# 9  <2> aassign[t2] KS/COMMON 
# a  <@> lineseq KP 
# b  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # sort numerically descending
@articles = sort {$b <=> $a} @files;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{@articles = sort {$b <=> $a} @files; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 817 (eval 23):1) v 
# 2  <#> gv[*files] s 
# 3  <1> rv2av[t7] lK/1 
# 4  <@> sort lK/DESC,NUM 
# 5  <@> list lK 
# 6  <#> gv[*articles] s 
# 7  <1> rv2av[t2] lKRM*/1 
# 8  <@> list lK 
# 9  <2> aassign[t3] KS/COMMON 
# a  <@> lineseq KP 
# b  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 835 (eval 23):1) v 
# 2  <$> gv(*files) s 
# 3  <1> rv2av[t3] lK/1 
# 4  <@> sort lK/DESC,NUM 
# 5  <@> list lK 
# 6  <$> gv(*articles) s 
# 7  <1> rv2av[t1] lKRM*/1 
# 8  <@> list lK 
# 9  <2> aassign[t2] KS/COMMON 
# a  <@> lineseq KP 
# b  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT


=for gentest

# chunk: # this sorts the %age hash by value instead of key
# using an in-line function
@eldest = sort { $age{$b} <=> $age{$a} } keys %age;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{@eldest = sort { $age{$b} <=> $age{$a} } keys %age; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 823 (eval 25):1) v 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*age] s 
# 4  <1> rv2hv sKR/1 
# 5  <#> gv[*b] s 
# 6  <1> rv2sv sK/1 
# 7  <2> helem sK/2 
# 8  <#> gv[*age] s 
# 9  <1> rv2hv sKR/1 
# a  <#> gv[*a] s 
# b  <1> rv2sv sK/1 
# c  <2> helem sK/2 
# d  <2> ncmp[t7] sK/2 
# e  <@> scope sK 
# f  <1> null sK/1 
# g  <#> gv[*age] s 
# h  <1> rv2hv[t9] lKRM/1 
# i  <1> keys[t10] lK/1 
# j  <@> sort lKS* 
# k  <@> list lK 
# l  <#> gv[*eldest] s 
# m  <1> rv2av[t2] lKRM*/1 
# n  <@> list lK 
# o  <2> aassign[t11] KS/COMMON 
# p  <@> lineseq KP 
# q  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 841 (eval 25):1) v 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*age) s 
# 4  <1> rv2hv sKR/1 
# 5  <$> gv(*b) s 
# 6  <1> rv2sv sK/1 
# 7  <2> helem sK/2 
# 8  <$> gv(*age) s 
# 9  <1> rv2hv sKR/1 
# a  <$> gv(*a) s 
# b  <1> rv2sv sK/1 
# c  <2> helem sK/2 
# d  <2> ncmp[t2] sK/2 
# e  <@> scope sK 
# f  <1> null sK/1 
# g  <$> gv(*age) s 
# h  <1> rv2hv[t3] lKRM/1 
# i  <1> keys[t4] lK/1 
# j  <@> sort lKS* 
# k  <@> list lK 
# l  <$> gv(*eldest) s 
# m  <1> rv2av[t1] lKRM*/1 
# n  <@> list lK 
# o  <2> aassign[t5] KS/COMMON 
# p  <@> lineseq KP 
# q  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # sort using explicit subroutine name
sub byage {
    $age{$a} <=> $age{$b};  # presuming numeric
}
@sortedclass = sort byage @class;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{sub byage { $age{$a} <=> $age{$b}; } @sortedclass = sort byage @class; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 829 (eval 27):1) v 
# 2  <$> const[PV "byage"] s/BARE 
# 3  <1> null lK/1 
# 4  <#> gv[*class] s 
# 5  <1> rv2av[t4] lK/1 
# 6  <@> sort lKS 
# 7  <@> list lK 
# 8  <#> gv[*sortedclass] s 
# 9  <1> rv2av[t2] lKRM*/1 
# a  <@> list lK 
# b  <2> aassign[t5] KS/COMMON 
# c  <@> lineseq KP 
# d  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 847 (eval 27):1) v 
# 2  <$> const(PV "byage") s/BARE 
# 3  <1> null lK/1 
# 4  <$> gv(*class) s 
# 5  <1> rv2av[t2] lK/1 
# 6  <@> sort lKS 
# 7  <@> list lK 
# 8  <$> gv(*sortedclass) s 
# 9  <1> rv2av[t1] lKRM*/1 
# a  <@> list lK 
# b  <2> aassign[t3] KS/COMMON 
# c  <@> lineseq KP 
# d  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: sub backwards { $b cmp $a }
@harry  = qw(dog cat x Cain Abel);
@george = qw(gone chased yz Punished Axed);
print sort @harry;
# prints AbelCaincatdogx
print sort backwards @harry;
# prints xdogcatCainAbel
print sort @george, 'to', @harry;
# prints AbelAxedCainPunishedcatchaseddoggonetoxyz

=cut

checkOptree(name   => q{sort USERSUB LIST },
	    bcopts => q{-exec},
	    code   => q{sub backwards { $b cmp $a }
			@harry = qw(dog cat x Cain Abel);
			@george = qw(gone chased yz Punished Axed);
			print sort @harry; print sort backwards @harry; 
			print sort @george, 'to', @harry; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 835 (eval 29):2) v 
# 2  <$> const[PV "dog"] s 
# 3  <$> const[PV "cat"] s 
# 4  <$> const[PV "x"] s 
# 5  <$> const[PV "Cain"] s 
# 6  <$> const[PV "Abel"] s 
# 7  <@> list lKP 
# 8  <#> gv[*harry] s 
# 9  <1> rv2av[t2] lKRM*/1 
# a  <@> list lK 
# b  <2> aassign[t3] vKS 
# c  <;> nextstate(main 835 (eval 29):3) v 
# d  <$> const[PV "gone"] s 
# e  <$> const[PV "chased"] s 
# f  <$> const[PV "yz"] s 
# g  <$> const[PV "Punished"] s 
# h  <$> const[PV "Axed"] s 
# i  <@> list lKP 
# j  <#> gv[*george] s 
# k  <1> rv2av[t5] lKRM*/1 
# l  <@> list lK 
# m  <2> aassign[t6] vKS 
# n  <;> nextstate(main 835 (eval 29):4) v:{ 
# o  <#> gv[*harry] s 
# p  <1> rv2av[t8] lK/1 
# q  <@> sort lK 
# r  <@> print vK 
# s  <;> nextstate(main 835 (eval 29):4) v:{ 
# t  <$> const[PV "backwards"] s/BARE 
# u  <1> null lK/1 
# v  <#> gv[*harry] s 
# w  <1> rv2av[t10] lK/1 
# x  <@> sort lKS 
# y  <@> print vK 
# z  <;> nextstate(main 835 (eval 29):5) v:{ 
# 10 <#> gv[*george] s 
# 11 <1> rv2av[t12] lK/1 
# 12 <$> const[PV "to"] s 
# 13 <#> gv[*harry] s 
# 14 <1> rv2av[t14] lK/1 
# 15 <@> sort lK 
# 16 <@> print sK 
# 17 <@> lineseq KP 
# 18 <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 853 (eval 29):2) v 
# 2  <$> const(PV "dog") s 
# 3  <$> const(PV "cat") s 
# 4  <$> const(PV "x") s 
# 5  <$> const(PV "Cain") s 
# 6  <$> const(PV "Abel") s 
# 7  <@> list lKP 
# 8  <$> gv(*harry) s 
# 9  <1> rv2av[t1] lKRM*/1 
# a  <@> list lK 
# b  <2> aassign[t2] vKS 
# c  <;> nextstate(main 853 (eval 29):3) v 
# d  <$> const(PV "gone") s 
# e  <$> const(PV "chased") s 
# f  <$> const(PV "yz") s 
# g  <$> const(PV "Punished") s 
# h  <$> const(PV "Axed") s 
# i  <@> list lKP 
# j  <$> gv(*george) s 
# k  <1> rv2av[t3] lKRM*/1 
# l  <@> list lK 
# m  <2> aassign[t4] vKS 
# n  <;> nextstate(main 853 (eval 29):4) v:{ 
# o  <$> gv(*harry) s 
# p  <1> rv2av[t5] lK/1 
# q  <@> sort lK 
# r  <@> print vK 
# s  <;> nextstate(main 853 (eval 29):4) v:{ 
# t  <$> const(PV "backwards") s/BARE 
# u  <1> null lK/1 
# v  <$> gv(*harry) s 
# w  <1> rv2av[t6] lK/1 
# x  <@> sort lKS 
# y  <@> print vK 
# z  <;> nextstate(main 853 (eval 29):5) v:{ 
# 10 <$> gv(*george) s 
# 11 <1> rv2av[t7] lK/1 
# 12 <$> const(PV "to") s 
# 13 <$> gv(*harry) s 
# 14 <1> rv2av[t8] lK/1 
# 15 <@> sort lK 
# 16 <@> print sK 
# 17 <@> lineseq KP 
# 18 <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # inefficiently sort by descending numeric compare using
# the first integer after the first = sign, or the
# whole record case-insensitively otherwise
@new = @old[ sort {
    $nums[$b] <=> $nums[$a]
	|| $caps[$a] cmp $caps[$b]
	} 0..$#old  ];

=cut
=for gentest

# chunk: # same thing, but without any temps
@new = map { $_->[0] }
sort { $b->[1] <=> $a->[1] 
	   || $a->[2] cmp $b->[2]
	   } map { [$_, /=(\d+)/, uc($_)] } @old;

=cut

checkOptree(name   => q{Compound sort/map Expression },
	    bcopts => q{-exec},
	    code   => q{ @new = map { $_->[0] }
			 sort { $b->[1] <=> $a->[1] || $a->[2] cmp $b->[2] }
			 map { [$_, /=(\d+)/, uc($_)] } @old; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 843 (eval 31):3) v:{ 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*_] s 
# 4  <1> rv2sv sKM/DREFAV,1 
# 5  <1> rv2av[t4] sKR/1 
# 6  <$> const[IV 0] s 
# 7  <2> aelem sK/2 
# 8  <@> scope lK 
# 9  <1> null lK/1 
# a  <1> null lK/1 
# b  <0> ex-nextstate v 
# c  <#> gv[*b] s 
# d  <1> rv2sv sKM/DREFAV,1 
# e  <1> rv2av[t6] sKR/1 
# f  <$> const[IV 1] s 
# g  <2> aelem sK/2 
# h  <#> gv[*a] s 
# i  <1> rv2sv sKM/DREFAV,1 
# j  <1> rv2av[t8] sKR/1 
# k  <$> const[IV 1] s 
# l  <2> aelem sK/2 
# m  <2> ncmp[t9] sK/2 
# n  <#> gv[*a] s 
# o  <1> rv2sv sKM/DREFAV,1 
# p  <1> rv2av[t11] sKR/1 
# q  <$> const[IV 2] s 
# r  <2> aelem sK/2 
# s  <#> gv[*b] s 
# t  <1> rv2sv sKM/DREFAV,1 
# u  <1> rv2av[t13] sKR/1 
# v  <$> const[IV 2] s 
# w  <2> aelem sK/2 
# x  <2> scmp[t14] sK/2 
# y  <|> or sK/1 
# z  <@> scope sK 
# 10 <1> null sK/1 
# 11 <0> enter l 
# 12 <;> nextstate(main 842 (eval 31):2) v:{ 
# 13 <#> gv[*_] s 
# 14 <1> rv2sv sK/1 
# 15 </> match(/"=(\\d+)"/) l/RTIME 
# 16 <#> gv[*_] s 
# 17 <1> rv2sv sK/1 
# 18 <1> uc[t17] sK/1 
# 19 <@> anonlist sK*/1 
# 1a <@> leave lKP 
# 1b <1> null lK/1 
# 1c <1> null lK/1 
# 1d <#> gv[*old] s 
# 1e <1> rv2av[t19] lKM/1 
# 1f <@> mapstart[t20] lK* 
# 1g <@> sort lKMS* 
# 1h <@> mapstart[t21] lK* 
# 1i <@> list lK 
# 1j <#> gv[*new] s 
# 1k <1> rv2av[t2] lKRM*/1 
# 1l <@> list lK 
# 1m <2> aassign[t22] KS/COMMON 
# 1n <@> lineseq KP 
# 1o <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 861 (eval 31):3) v:{ 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*_) s 
# 4  <1> rv2sv sKM/DREFAV,1 
# 5  <1> rv2av[t2] sKR/1 
# 6  <$> const(IV 0) s 
# 7  <2> aelem sK/2 
# 8  <@> scope lK 
# 9  <1> null lK/1 
# a  <1> null lK/1 
# b  <0> ex-nextstate v 
# c  <$> gv(*b) s 
# d  <1> rv2sv sKM/DREFAV,1 
# e  <1> rv2av[t3] sKR/1 
# f  <$> const(IV 1) s 
# g  <2> aelem sK/2 
# h  <$> gv(*a) s 
# i  <1> rv2sv sKM/DREFAV,1 
# j  <1> rv2av[t4] sKR/1 
# k  <$> const(IV 1) s 
# l  <2> aelem sK/2 
# m  <2> ncmp[t5] sK/2 
# n  <$> gv(*a) s 
# o  <1> rv2sv sKM/DREFAV,1 
# p  <1> rv2av[t6] sKR/1 
# q  <$> const(IV 2) s 
# r  <2> aelem sK/2 
# s  <$> gv(*b) s 
# t  <1> rv2sv sKM/DREFAV,1 
# u  <1> rv2av[t7] sKR/1 
# v  <$> const(IV 2) s 
# w  <2> aelem sK/2 
# x  <2> scmp[t8] sK/2 
# y  <|> or sK/1 
# z  <@> scope sK 
# 10 <1> null sK/1 
# 11 <0> enter l 
# 12 <;> nextstate(main 860 (eval 31):2) v:{ 
# 13 <$> gv(*_) s 
# 14 <1> rv2sv sK/1 
# 15 </> match(/"=(\\d+)"/) l/RTIME 
# 16 <$> gv(*_) s 
# 17 <1> rv2sv sK/1 
# 18 <1> uc[t9] sK/1 
# 19 <@> anonlist sK*/1 
# 1a <@> leave lKP 
# 1b <1> null lK/1 
# 1c <1> null lK/1 
# 1d <$> gv(*old) s 
# 1e <1> rv2av[t10] lKM/1 
# 1f <@> mapstart[t11] lK* 
# 1g <@> sort lKMS* 
# 1h <@> mapstart[t12] lK* 
# 1i <@> list lK 
# 1j <$> gv(*new) s 
# 1k <1> rv2av[t1] lKRM*/1 
# 1l <@> list lK 
# 1m <2> aassign[t13] KS/COMMON 
# 1n <@> lineseq KP 
# 1o <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # using a prototype allows you to use any comparison subroutine
# as a sort subroutine (including other package's subroutines)
package other;
sub backwards ($$) { $_[1] cmp $_[0]; }     # $a and $b are not set here
package main;
@new = sort other::backwards @old;

=cut

checkOptree(name   => q{sort other::sub LIST },
	    bcopts => q{-exec},
	    code   => q{package other; sub backwards ($$) { $_[1] cmp $_[0]; }
			package main; @new = sort other::backwards @old; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 849 (eval 33):2) v:{ 
# 2  <$> const[PV "other::backwards"] s/BARE 
# 3  <1> null lK/1 
# 4  <#> gv[*old] s 
# 5  <1> rv2av[t4] lK/1 
# 6  <@> sort lKS 
# 7  <@> list lK 
# 8  <#> gv[*new] s 
# 9  <1> rv2av[t2] lKRM*/1 
# a  <@> list lK 
# b  <2> aassign[t5] KS/COMMON 
# c  <@> lineseq KP 
# d  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 867 (eval 33):2) v:{ 
# 2  <$> const(PV "other::backwards") s/BARE 
# 3  <1> null lK/1 
# 4  <$> gv(*old) s 
# 5  <1> rv2av[t2] lK/1 
# 6  <@> sort lKS 
# 7  <@> list lK 
# 8  <$> gv(*new) s 
# 9  <1> rv2av[t1] lKRM*/1 
# a  <@> list lK 
# b  <2> aassign[t3] KS/COMMON 
# c  <@> lineseq KP 
# d  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # repeat, condensed. $main::a and $b are unaffected
sub other::backwards ($$) { $_[1] cmp $_[0]; }
@new = sort other::backwards @old;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{sub other::backwards ($$) { $_[1] cmp $_[0]; } @new = sort other::backwards @old; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 855 (eval 35):1) v 
# 2  <$> const[PV "other::backwards"] s/BARE 
# 3  <1> null lK/1 
# 4  <#> gv[*old] s 
# 5  <1> rv2av[t4] lK/1 
# 6  <@> sort lKS 
# 7  <@> list lK 
# 8  <#> gv[*new] s 
# 9  <1> rv2av[t2] lKRM*/1 
# a  <@> list lK 
# b  <2> aassign[t5] KS/COMMON 
# c  <@> lineseq KP 
# d  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 873 (eval 35):1) v 
# 2  <$> const(PV "other::backwards") s/BARE 
# 3  <1> null lK/1 
# 4  <$> gv(*old) s 
# 5  <1> rv2av[t2] lK/1 
# 6  <@> sort lKS 
# 7  <@> list lK 
# 8  <$> gv(*new) s 
# 9  <1> rv2av[t1] lKRM*/1 
# a  <@> list lK 
# b  <2> aassign[t3] KS/COMMON 
# c  <@> lineseq KP 
# d  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # guarantee stability, regardless of algorithm
use sort 'stable';
@new = sort { substr($a, 3, 5) cmp substr($b, 3, 5) } @old;

=cut

my ($expect, $expect_nt) = (<<'EOT_EOT', <<'EONT_EONT');
# 1  <;> nextstate(main 891 (eval 37):1) v:%,{ 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*a] s 
# 4  <1> rv2sv sK/1 
# 5  <$> const[IV 3] s 
# 6  <$> const[IV 5] s 
# 7  <@> substr[t4] sK/3 
# 8  <#> gv[*b] s 
# 9  <1> rv2sv sK/1 
# a  <$> const[IV 3] s 
# b  <$> const[IV 5] s 
# c  <@> substr[t6] sK/3 
# d  <2> scmp[t7] sK/2 
# e  <@> scope sK 
# f  <1> null sK/1 
# g  <#> gv[*old] s 
# h  <1> rv2av[t9] lK/1 
# i  <@> sort lKS*/STABLE 
# j  <@> list lK 
# k  <#> gv[*new] s 
# l  <1> rv2av[t2] lKRM*/1 
# m  <@> list lK 
# n  <2> aassign[t10] KS/COMMON 
# o  <@> lineseq KP 
# p  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 909 (eval 37):1) v:%,{ 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*a) s 
# 4  <1> rv2sv sK/1 
# 5  <$> const(IV 3) s 
# 6  <$> const(IV 5) s 
# 7  <@> substr[t2] sK/3 
# 8  <$> gv(*b) s 
# 9  <1> rv2sv sK/1 
# a  <$> const(IV 3) s 
# b  <$> const(IV 5) s 
# c  <@> substr[t3] sK/3 
# d  <2> scmp[t4] sK/2 
# e  <@> scope sK 
# f  <1> null sK/1 
# g  <$> gv(*old) s 
# h  <1> rv2av[t5] lK/1 
# i  <@> sort lKS*/STABLE 
# j  <@> list lK 
# k  <$> gv(*new) s 
# l  <1> rv2av[t1] lKRM*/1 
# m  <@> list lK 
# n  <2> aassign[t6] KS/COMMON 
# o  <@> lineseq KP 
# p  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT

if($] < 5.009) {
    # 5.8.x doesn't show the /STABLE flag, so massage the golden results.
    s!/STABLE!!s foreach ($expect, $expect_nt);
}

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{use sort 'stable'; @new = sort { substr($a, 3, 5) cmp substr($b, 3, 5) } @old; },
	    expect => $expect, expect_nt => $expect_nt);

=for gentest

# chunk: # force use of mergesort (not portable outside Perl 5.8)
use sort '_mergesort';
@new = sort { substr($a, 3, 5) cmp substr($b, 3, 5) } @old;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{use sort '_mergesort'; @new = sort { substr($a, 3, 5) cmp substr($b, 3, 5) } @old; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 898 (eval 39):1) v:%,{ 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*a] s 
# 4  <1> rv2sv sK/1 
# 5  <$> const[IV 3] s 
# 6  <$> const[IV 5] s 
# 7  <@> substr[t4] sK/3 
# 8  <#> gv[*b] s 
# 9  <1> rv2sv sK/1 
# a  <$> const[IV 3] s 
# b  <$> const[IV 5] s 
# c  <@> substr[t6] sK/3 
# d  <2> scmp[t7] sK/2 
# e  <@> scope sK 
# f  <1> null sK/1 
# g  <#> gv[*old] s 
# h  <1> rv2av[t9] lK/1 
# i  <@> sort lKS* 
# j  <@> list lK 
# k  <#> gv[*new] s 
# l  <1> rv2av[t2] lKRM*/1 
# m  <@> list lK 
# n  <2> aassign[t10] KS/COMMON 
# o  <@> lineseq KP 
# p  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 916 (eval 39):1) v:%,{ 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*a) s 
# 4  <1> rv2sv sK/1 
# 5  <$> const(IV 3) s 
# 6  <$> const(IV 5) s 
# 7  <@> substr[t2] sK/3 
# 8  <$> gv(*b) s 
# 9  <1> rv2sv sK/1 
# a  <$> const(IV 3) s 
# b  <$> const(IV 5) s 
# c  <@> substr[t3] sK/3 
# d  <2> scmp[t4] sK/2 
# e  <@> scope sK 
# f  <1> null sK/1 
# g  <$> gv(*old) s 
# h  <1> rv2av[t5] lK/1 
# i  <@> sort lKS* 
# j  <@> list lK 
# k  <$> gv(*new) s 
# l  <1> rv2av[t1] lKRM*/1 
# m  <@> list lK 
# n  <2> aassign[t6] KS/COMMON 
# o  <@> lineseq KP 
# p  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # you should have a good reason to do this!
@articles = sort {$FooPack::b <=> $FooPack::a} @files;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{@articles = sort {$FooPack::b <=> $FooPack::a} @files; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 904 (eval 41):1) v 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*FooPack::b] s 
# 4  <1> rv2sv sK/1 
# 5  <#> gv[*FooPack::a] s 
# 6  <1> rv2sv sK/1 
# 7  <2> ncmp[t5] sK/2 
# 8  <@> scope sK 
# 9  <1> null sK/1 
# a  <#> gv[*files] s 
# b  <1> rv2av[t7] lK/1 
# c  <@> sort lKS* 
# d  <@> list lK 
# e  <#> gv[*articles] s 
# f  <1> rv2av[t2] lKRM*/1 
# g  <@> list lK 
# h  <2> aassign[t8] KS/COMMON 
# i  <@> lineseq KP 
# j  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 922 (eval 41):1) v 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*FooPack::b) s 
# 4  <1> rv2sv sK/1 
# 5  <$> gv(*FooPack::a) s 
# 6  <1> rv2sv sK/1 
# 7  <2> ncmp[t2] sK/2 
# 8  <@> scope sK 
# 9  <1> null sK/1 
# a  <$> gv(*files) s 
# b  <1> rv2av[t3] lK/1 
# c  <@> sort lKS* 
# d  <@> list lK 
# e  <$> gv(*articles) s 
# f  <1> rv2av[t1] lKRM*/1 
# g  <@> list lK 
# h  <2> aassign[t4] KS/COMMON 
# i  <@> lineseq KP 
# j  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # fancy
@result = sort { $a <=> $b } grep { $_ == $_ } @input;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{@result = sort { $a <=> $b } grep { $_ == $_ } @input; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 911 (eval 43):1) v 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*_] s 
# 4  <1> rv2sv sK/1 
# 5  <#> gv[*_] s 
# 6  <1> rv2sv sK/1 
# 7  <2> eq sK/2 
# 8  <@> scope sK 
# 9  <1> null sK/1 
# a  <1> null lK/1 
# b  <#> gv[*input] s 
# c  <1> rv2av[t9] lKM/1 
# d  <@> grepstart[t10] lK* 
# e  <@> sort lK/NUM 
# f  <@> list lK 
# g  <#> gv[*result] s 
# h  <1> rv2av[t2] lKRM*/1 
# i  <@> list lK 
# j  <2> aassign[t3] KS/COMMON 
# k  <@> lineseq KP 
# l  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 929 (eval 43):1) v 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*_) s 
# 4  <1> rv2sv sK/1 
# 5  <$> gv(*_) s 
# 6  <1> rv2sv sK/1 
# 7  <2> eq sK/2 
# 8  <@> scope sK 
# 9  <1> null sK/1 
# a  <1> null lK/1 
# b  <$> gv(*input) s 
# c  <1> rv2av[t3] lKM/1 
# d  <@> grepstart[t4] lK* 
# e  <@> sort lK/NUM 
# f  <@> list lK 
# g  <$> gv(*result) s 
# h  <1> rv2av[t1] lKRM*/1 
# i  <@> list lK 
# j  <2> aassign[t2] KS/COMMON 
# k  <@> lineseq KP 
# l  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # void return context sort
sort { $a <=> $b } @input;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{sort { $a <=> $b } @input; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 917 (eval 45):1) v 
# 2  <#> gv[*input] s 
# 3  <1> rv2av[t5] lK/1 
# 4  <@> sort K/NUM 
# 5  <@> lineseq KP 
# 6  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 935 (eval 45):1) v 
# 2  <$> gv(*input) s 
# 3  <1> rv2av[t2] lK/1 
# 4  <@> sort K/NUM 
# 5  <@> lineseq KP 
# 6  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # more void context, propagating ?
sort { $a <=> $b } grep { $_ == $_ } @input;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{sort { $a <=> $b } grep { $_ == $_ } @input; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 924 (eval 47):1) v 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*_] s 
# 4  <1> rv2sv sK/1 
# 5  <#> gv[*_] s 
# 6  <1> rv2sv sK/1 
# 7  <2> eq sK/2 
# 8  <@> scope sK 
# 9  <1> null sK/1 
# a  <1> null lK/1 
# b  <#> gv[*input] s 
# c  <1> rv2av[t7] lKM/1 
# d  <@> grepstart[t8] lK* 
# e  <@> sort K/NUM 
# f  <@> lineseq KP 
# g  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 942 (eval 47):1) v 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*_) s 
# 4  <1> rv2sv sK/1 
# 5  <$> gv(*_) s 
# 6  <1> rv2sv sK/1 
# 7  <2> eq sK/2 
# 8  <@> scope sK 
# 9  <1> null sK/1 
# a  <1> null lK/1 
# b  <$> gv(*input) s 
# c  <1> rv2av[t2] lKM/1 
# d  <@> grepstart[t3] lK* 
# e  <@> sort K/NUM 
# f  <@> lineseq KP 
# g  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: # scalar return context sort
$s = sort { $a <=> $b } @input;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{$s = sort { $a <=> $b } @input; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 930 (eval 49):1) v:{ 
# 2  <#> gv[*input] s 
# 3  <1> rv2av[t6] lK/1 
# 4  <@> sort sK/NUM 
# 5  <#> gv[*s] s 
# 6  <1> rv2sv sKRM*/1 
# 7  <2> sassign sKS/2 
# 8  <@> lineseq KP 
# 9  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 948 (eval 49):1) v:{ 
# 2  <$> gv(*input) s 
# 3  <1> rv2av[t2] lK/1 
# 4  <@> sort sK/NUM 
# 5  <$> gv(*s) s 
# 6  <1> rv2sv sKRM*/1 
# 7  <2> sassign sKS/2 
# 8  <@> lineseq KP 
# 9  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    

=for gentest

# chunk: $s = sort { $a <=> $b } grep { $_ == $_ } @input;

=cut

checkOptree(note   => q{},
	    bcopts => q{-exec},
	    code   => q{$s = sort { $a <=> $b } grep { $_ == $_ } @input; },
	    expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 937 (eval 51):1) v:{ 
# 2  <0> ex-nextstate v 
# 3  <#> gv[*_] s 
# 4  <1> rv2sv sK/1 
# 5  <#> gv[*_] s 
# 6  <1> rv2sv sK/1 
# 7  <2> eq sK/2 
# 8  <@> scope sK 
# 9  <1> null sK/1 
# a  <1> null lK/1 
# b  <#> gv[*input] s 
# c  <1> rv2av[t8] lKM/1 
# d  <@> grepstart[t9] lK* 
# e  <@> sort sK/NUM 
# f  <#> gv[*s] s 
# g  <1> rv2sv sKRM*/1 
# h  <2> sassign sKS/2 
# i  <@> lineseq KP 
# j  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 955 (eval 51):1) v:{ 
# 2  <0> ex-nextstate v 
# 3  <$> gv(*_) s 
# 4  <1> rv2sv sK/1 
# 5  <$> gv(*_) s 
# 6  <1> rv2sv sK/1 
# 7  <2> eq sK/2 
# 8  <@> scope sK 
# 9  <1> null sK/1 
# a  <1> null lK/1 
# b  <$> gv(*input) s 
# c  <1> rv2av[t2] lKM/1 
# d  <@> grepstart[t3] lK* 
# e  <@> sort sK/NUM 
# f  <$> gv(*s) s 
# g  <1> rv2sv sKRM*/1 
# h  <2> sassign sKS/2 
# i  <@> lineseq KP 
# j  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT
    
