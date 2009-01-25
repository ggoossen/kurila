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

# import checkOptree(), and %gOpts (containing test state)
use OptreeCheck;	# ALSO DOES @ARGV HANDLING !!!!!!
use Config;

my $tests = 8;
plan tests => $tests;
SKIP: do {
skip "no perlio in this build", $tests unless Config::config_value("useperlio");

$^WARN_HOOK = sub {
    my $err = shift;
    $err->message =~ m/Subroutine re::(un)?install redefined/ and return;
};
#################################
pass("CANONICAL B::Concise EXAMPLE");

#################################
pass("B::Concise OPTION TESTS");

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
	    my @($h, $op, $format, $level, $style) =  @_;

	    # callback marks up const ops
	    $h->{+arg} .= ' CALLBACK' if $h->{?name} eq 'const';
	    $h->{+extra} = '';

	    # 2 style specific behaviors
	    if ($style eq 'relative') {
		$h->{+extra} = 'RELATIVE';
		$h->{+arg} .= ' RELATIVE' if $h->{?name} eq 'leavesub';
	    }
	    elsif ($style eq 'scope') {
		# supress printout entirely
		$$format="" unless grep { $h->{?name} eq $_ } @scopeops;
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

}; #skip

