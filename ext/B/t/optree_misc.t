#!perl

BEGIN {
    unshift @INC, 't';
    require Config;
    if (($Config::Config{'extensions'} !~ /\bB\b/) ){
        print "1..0 # Skip -- Perl configured without B module\n";
        exit 0;
    }
}
use OptreeCheck;
use Config;
plan tests => 6;

SKIP: {
skip "no perlio in this build", 4 unless $Config::Config{useperlio};

# The regression this was testing is that the first aelemfast, derived
# from a lexical array, is supposed to be a BASEOP "<0>", while the
# second, from a global, is an SVOP "<$>" or a PADOP "<#>" depending
# on threading. In buggy versions, both showed up as SVOPs/PADOPs. See
# B.xs:cc_opclass() for the relevant code.

# All this is much simpler, now that aelemfast_lex has been broken out from
# aelemfast
checkOptree ( name	=> 'OP_AELEMFAST opclass',
	      code	=> sub { my @x; our @y; $x[0] + $y[0]},
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# g  <1> leavesub[1 ref] K/REFC,1 
# f     <@> lineseq KP 
# 1        <;> nextstate(main 716 optree_misc.t:25) v 
# 2        <0> padav[@x:716,718] vM/LVINTRO 
# 3        <;> nextstate(main 717 optree_misc.t:25) v 
# 5        <1> rv2av[t4] vK/OURINTR,1 
# 4           <#> gv[*y] s 
# 6        <;> nextstate(main 718 optree_misc.t:25) v:{ 
# e        <2> add[t6] sK/2 
# 9           <2> aelem sK/2 
# 7              <0> padav[@x:716,718] sR 
# 8              <$> const[IV 0] s 
# d           <2> aelem sK/2 
# b              <1> rv2av sKR/1 
# a                 <#> gv[*y] s 
# c              <$> const[IV 0] s 
EOT_EOT
# g  <1> leavesub[1 ref] K/REFC,1 
# f     <@> lineseq KP 
# 1        <;> nextstate(main 716 optree_misc.t:25) v 
# 2        <0> padav[@x:716,718] vM/LVINTRO 
# 3        <;> nextstate(main 717 optree_misc.t:25) v 
# 5        <1> rv2av[t3] vK/OURINTR,1 
# 4           <$> gv(*y) s 
# 6        <;> nextstate(main 718 optree_misc.t:25) v:{ 
# e        <2> add[t4] sK/2 
# 9           <2> aelem sK/2 
# 7              <0> padav[@x:716,718] sR 
# 8              <$> const(IV 0) s 
# d           <2> aelem sK/2 
# b              <1> rv2av sKR/1 
# a                 <$> gv(*y) s 
# c              <$> const(IV 0) s 
EONT_EONT

checkOptree ( name	=> 'PMOP children',
	      code	=> sub { $foo =~ s/(a)/$1/ },
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 9  <1> leavesub[1 ref] K/REFC,1 
# 8     <@> lineseq KP 
# 1        <;> nextstate(main 829 optree_misc.t:64) v:{ 
# 7        </> subst(/"(a)"/) KS 
# 3           <1> rv2sv sKRM/1 
# 2              <#> gv[*foo] s 
# 6           <|> substcont sK/1 
# 5              <1> rv2sv sK/1 
# 4                 <#> gv[*1] s 
EOT_EOT
# 9  <1> leavesub[1 ref] K/REFC,1 
# 8     <@> lineseq KP 
# 1        <;> nextstate(main 829 optree_misc.t:64) v:{ 
# 7        </> subst(/"(a)"/) KS 
# 3           <1> rv2sv sKRM/1 
# 2              <$> gv(*foo) s 
# 6           <|> substcont sK/1 
# 5              <1> rv2sv sK/1 
# 4                 <$> gv(*1) s 
EONT_EONT

} #skip

my $t = <<'EOT_EOT';
# 9  <@> leave[1 ref] vKP/REFC 
# 1     <0> enter 
# 2     <;> nextstate(main 1 -e:1) v:{ 
# 8     <2> sassign vKS/2 
# 5        <@> index[t2] sK/2 
# 3           <$> const[PV "foo"] s 
# 4           <$> const[GV "foo"] s 
# 7        <1> rv2sv sKRM*/1 
# 6           <#> gv[*_] s 
EOT_EOT
my $nt = <<'EONT_EONT';
# 9  <@> leave[1 ref] vKP/REFC 
# 1     <0> enter 
# 2     <;> nextstate(main 1 -e:1) v:{ 
# 8     <2> sassign vKS/2 
# 5        <@> index[t1] sK/2 
# 3           <$> const(PV "foo") s 
# 4           <$> const(GV "foo") s 
# 7        <1> rv2sv sKRM*/1 
# 6           <$> gv(*_) s 
EONT_EONT

if ($] < 5.009) {
    $t =~ s/GV /BM /;
    $nt =~ s/GV /BM /;
} 

checkOptree ( name      => 'index and PVBM',
	      prog	=> '$_ = index q(foo), q(foo)',
	      strip_open_hints => 1,
	      expect	=> $t,  expect_nt => $nt);
