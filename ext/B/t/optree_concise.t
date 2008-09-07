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

# import checkOptree(), and %gOpts (containing test state)
use OptreeCheck;	# ALSO DOES @ARGV HANDLING !!!!!!
use Config;

my $tests = 10;
plan tests => $tests;
SKIP: {
skip "no perlio in this build", $tests unless %Config::Config{useperlio};

$^WARN_HOOK = sub {
    my $err = shift;
    $err->message =~ m/Subroutine re::(un)?install redefined/ and return;
};
#################################
pass("CANONICAL B::Concise EXAMPLE");

checkOptree ( name	=> 'canonical example w -exec',
	      bcopts	=> '-exec',
	      code	=> sub{$a=$b+42},
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 61 optree_concise.t:139) v:{
# 2  <#> gvsv[*b] s
# 3  <$> const[IV 42] s
# 4  <2> add[t3] sK/2
# 5  <#> gvsv[*a] s
# 6  <2> sassign sKS/2
# 7  <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 61 optree_concise.t:139) v:{
# 2  <$> gvsv(*b) s
# 3  <$> const(IV 42) s
# 4  <2> add[t1] sK/2
# 5  <$> gvsv(*a) s
# 6  <2> sassign sKS/2
# 7  <1> leavesub[1 ref] K/REFC,1
EONT_EONT

#################################
pass("B::Concise OPTION TESTS");

checkOptree ( name	=> '-base3 sticky-exec',
	      bcopts	=> '-base3',
	      code	=> sub{$a=$b+42},
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <;> dbstate(main 24 optree_concise.t:132) v:{
2  <#> gvsv[*b] s
10 <$> const[IV 42] s
11 <2> add[t3] sK/2
12 <#> gvsv[*a] s
20 <2> sassign sKS/2
21 <1> leavesub[1 ref] K/REFC,1
EOT_EOT
# 1  <;> nextstate(main 62 optree_concise.t:161) v:{
# 2  <$> gvsv(*b) s
# 10 <$> const(IV 42) s
# 11 <2> add[t1] sK/2
# 12 <$> gvsv(*a) s
# 20 <2> sassign sKS/2
# 21 <1> leavesub[1 ref] K/REFC,1
EONT_EONT

pass("OPTIONS IN CMDLINE MODE");

checkOptree ( name => 'cmdline invoke -basic works',
	      prog => 'sort our @a',
	      errs => \@( 'Useless use of sort in void context at -e line 1.',
			'Name "main::a" used only once: possible typo at -e line 1.',
			),
	      #bcopts	=> '-basic', # default
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 7  <@> leave[1 ref] vKP/REFC ->(end)
# 1     <0> enter ->2
# 2     <;> nextstate(main 1 -e:1) v:{ ->3
# 6     <@> sort vK ->7
# 3        <0> pushmark s ->4
# 5        <1> rv2av[t2] lK/1 ->6
# 4           <#> gv[*a] s ->5
EOT_EOT
# 7  <@> leave[1 ref] vKP/REFC ->(end)
# 1     <0> enter ->2
# 2     <;> nextstate(main 1 -e:1) v:{ ->3
# 6     <@> sort vK ->7
# 3        <0> pushmark s ->4
# 5        <1> rv2av[t2] lK/OURINTR,1 ->6
# 4           <$> gv(*a) s ->5
EONT_EONT

checkOptree ( name => 'cmdline invoke -exec works',
	      prog => 'sort our @a',
	      errs => \@( 'Useless use of sort in void context at -e line 1.',
			'Name "main::a" used only once: possible typo at -e line 1.',
			),
	      bcopts => '-exec',
	      expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
1  <0> enter 
2  <;> nextstate(main 1 -e:1) v:{
3  <0> pushmark s
4  <#> gv[*a] s
5  <1> rv2av[t2] lK/1
6  <@> sort vK
7  <@> leave[1 ref] vKP/REFC
EOT_EOT
# 1  <0> enter 
# 2  <;> nextstate(main 1 -e:1) v:{
# 3  <0> pushmark s
# 4  <$> gv(*a) s
# 5  <1> rv2av[t2] lK/OURINTR,1
# 6  <@> sort vK
# 7  <@> leave[1 ref] vKP/REFC
EONT_EONT

;

checkOptree
    ( name	=> 'cmdline self-strict compile err using prog',
      prog	=> 'sort @a',
      bcopts	=> \qw/ -basic -concise -exec /,
      errs	=> 'Global symbol "@a" requires explicit package name at -e line 1.',
      expect	=> 'nextstate',
      expect_nt	=> 'nextstate',
      noanchors => 1, # allow simple expectations to work
      );

#################################
pass("B::Concise STYLE/CALLBACK TESTS");

use B::Concise < qw( walk_output add_style set_style_standard add_callback );

# new relative style, added by set_up_relative_test()
my @stylespec =
    @( "#hyphseq2 (*(   (x( ;)x))*)<#classsym> "
      . "#exname#arg(?([#targarglife])?)~#flags(?(/#privateb)?)(x(;~->#next)x) "
      . "(x(;~=> #extra)x)\n" # new 'variable' used here
      
      , "  (*(    )*)     goto #seq\n"
      , "(?(<#seq>)?)#exname#arg(?([#targarglife])?)"
      #. "(x(;~=> #extra)x)\n" # new 'variable' used here
      );
our @scopeops;

sub set_up_relative_test {
    # add a new style, and a callback which adds an 'extra' property

    add_style ( "relative"	=> < @stylespec );
    #set_style_standard ( "relative" );

    add_callback
	( sub {
	    my ($h, $op, $format, $level, $style) = < @_;

	    # callback marks up const ops
	    $h->{arg} .= ' CALLBACK' if $h->{name} eq 'const';
	    $h->{extra} = '';

	    # 2 style specific behaviors
	    if ($style eq 'relative') {
		$h->{extra} = 'RELATIVE';
		$h->{arg} .= ' RELATIVE' if $h->{name} eq 'leavesub';
	    }
	    elsif ($style eq 'scope') {
		# supress printout entirely
		$$format="" unless grep { $h->{name} eq $_ } @scopeops;
	    }
	});
}

#################################
set_up_relative_test();
pass("set_up_relative_test, new callback installed");

#################################

@scopeops = qw( leavesub enter leave nextstate );
add_style
	( 'scope'  # concise copy
	  , "#hyphseq2 (*(   (x( ;)x))*)<#classsym> "
	  . "#exname#arg(?([#targarglife])?)~#flags(?(/#private)?)(x(;~->#next)x) "
	  , "  (*(    )*)     goto #seq\n"
	  , "(?(<#seq>)?)#exname#arg(?([#targarglife])?)"
	 );

} #skip

