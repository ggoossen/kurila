#!perl

BEGIN {
    if (%ENV{PERL_CORE}){
	push @INC, '../ext/B/t';
    } else {
	unshift @INC, 't';
	push @INC, "../../t";
    }
}

use OptreeCheck;

=head1 OptreeCheck selftest harness

This file is primarily to test services of OptreeCheck itself, ie
checkOptree().  %gOpts provides test-state info, it is 'exported' into
main::  

doing use OptreeCheck runs import(), which processes @ARGV to process
cmdline args in 'standard' way across all clients of OptreeCheck.

=cut

our %gOpts;

my $tests = 15 + 16 * %gOpts{selftest};	# pass()s + $#tests
plan tests => $tests;

SKIP: do {
    skip "no perlio in this build", $tests
    unless Config::config_value("useperlio");


pass("REGEX TEST HARNESS SELFTEST");

checkOptree ( name	=> "bare minimum opcode search",
	      bcopts	=> '-exec',
	      code	=> sub {my $a},
	      noanchors	=> 1, # unanchored match
	      expect	=> 'leavesub',
	      expect_nt	=> 'leavesub');

checkOptree ( name	=> "found print opcode",
	      bcopts	=> '-exec',
	      code	=> sub {print 1},
	      noanchors	=> 1, # unanchored match
	      expect	=> 'print',
	      expect_nt	=> 'leavesub');

checkOptree ( name	=> 'test skip itself',
	      skip	=> 'this is skip-reason',
	      bcopts	=> '-exec',
	      code	=> sub {print 1},
	      expect	=> 'dont-care, skipping',
	      expect_nt	=> 'this insures failure');

# This test 'unexpectedly succeeds', but that is "expected".  Theres
# no good way to expect a successful todo, and inducing a failure
# causes the harness to print verbose errors, which is NOT helpful.

checkOptree ( name	=> 'test todo itself',
	      todo	=> "your excuse here ;-)",
	      bcopts	=> '-exec',
	      code	=> sub {print 1},
	      noanchors	=> 1, # unanchored match
	      expect	=> 'print',
	      expect_nt	=> 'print') if 0;

checkOptree ( name	=> 'impossible match, remove skip to see failure',
	      todo	=> "see! it breaks!",
	      skip	=> 'skip the failure',
	      code	=> sub {print 1},
	      expect	=> 'look out ! Boy Wonder',
	      expect_nt	=> 'holy near earth asteroid Batman !');

pass ("TEST FATAL ERRS");

if (1) {
    # test for fatal errors. Im unsettled on fail vs die.
    # calling fail isnt good enough by itself.

    $@='';
    try {
	checkOptree ( name	=> 'test against empty expectations',
		      bcopts	=> '-exec',
		      code	=> sub {print 1},
		      expect	=> '',
		      expect_nt	=> '');
    };
    like($@->{description}, m/no '\w+' golden-sample found/, "empty expectations prevented");
    
    $@='';
    try {
	checkOptree ( name	=> 'prevent whitespace only expectations',
		      bcopts	=> '-exec',
		      code	=> sub {my $a},
		      #skip	=> 1,
		      expect_nt	=> "\n",
		      expect	=> "\n");
    };
    like($@->{description}, m/no '\w+' golden-sample found/,
	 "just whitespace expectations prevented");
}
    
pass ("TEST -e \$srcCode");

checkOptree ( name	=> 'empty code or prog',
	      skip	=> 'or fails',
	      todo	=> "your excuse here ;-)",
	      code	=> '',
	      prog	=> '',
	      );

pass ("REFTEXT FIXUP TESTS");

checkOptree ( name	=> 'fixup nextstate (in reftext)',
	      bcopts	=> '-exec',
	      code	=> sub {my $a},
	      expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 54 optree_concise.t:84) v
# 2  <0> padsv[$a:54,55] sM/LVINTRO
# 3  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

checkOptree ( name	=> 'fixup opcode args',
	      bcopts	=> '-exec',
	      #fail	=> 1, # uncomment to see real padsv args: [$a:491,492] 
	      code	=> sub {my $a},
	      expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 56 optree_concise.t:96) v
# 2  <0> padsv[$a:56,57] sM/LVINTRO
# 3  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

#################################
pass("CANONICAL B::Concise EXAMPLE");

checkOptree ( name	=> 'canonical example w -basic',
	      bcopts	=> '-basic',
	      code	=>  sub{$a=$b+42},
	      crossfail => 1,
	      debug	=> 1,
	      expect_nt => <<'EONT_EONT');
# 7  <1> leavesub[1 ref] K/REFC,1 ->(end)
# -     <@> lineseq sKP ->7
# 1        <;> nextstate(main 60 optree_concise.t:122) v:{ ->2
# 6        <2> sassign sKS/2 ->7
# 4           <2> add[t1] sK/2 ->5
# -              <1> ex-rv2sv sK/1 ->3
# 2                 <$> gvsv(*b) s ->3
# 3              <$> const(IV 42) s ->4
# -           <1> ex-rv2sv sKRM*/1 ->6
# 5              <$> gvsv(*a) s ->6
EONT_EONT

};

__END__

