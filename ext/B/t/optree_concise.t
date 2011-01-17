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

# import checkOptree(), and %gOpts (containing test state)
use OptreeCheck;	# ALSO DOES @ARGV HANDLING !!!!!!
use Config;

plan tests => 41;

$SIG{__WARN__} = sub {
    my $err = shift;
    $err =~ m/Subroutine re::(un)?install redefined/ and return;
};
#################################
pass("CANONICAL B::Concise EXAMPLE");

checkOptree ( name	=> 'canonical example w -basic',
	      bcopts	=> '-basic',
	      code	=>  sub{$a=$b+42},
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# a  <1> leavesub[1 ref] K/REFC,1 
# 9     <@> lineseq KP 
# 1        <;> nextstate(main 704 optree_concise.t:29) v:{ 
# 8        <2> sassign sKS/2 
# 5           <2> add[t3] sK/2 
# 3              <1> rv2sv sK/1 
# 2                 <#> gv[*b] s 
# 4              <$> const[IV 42] s 
# 7           <1> rv2sv sKRM*/1 
# 6              <#> gv[*a] s 
EOT_EOT
# a  <1> leavesub[1 ref] K/REFC,1 
# 9     <@> lineseq KP 
# 1        <;> nextstate(main 704 optree_concise.t:29) v:{ 
# 8        <2> sassign sKS/2 
# 5           <2> add[t3] sK/2 
# 3              <1> rv2sv sK/1 
# 2                 <$> gv(*b) s 
# 4              <$> const(IV 42) s 
# 7           <1> rv2sv sKRM*/1 
# 6              <$> gv(*a) s 
EONT_EONT

checkOptree ( name	=> 'canonical example w -exec',
	      bcopts	=> '-exec',
	      code	=> sub{$a=$b+42},
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 705 optree_concise.t:57) v:{ 
# 2  <#> gv[*b] s 
# 3  <1> rv2sv sK/1 
# 4  <$> const[IV 42] s 
# 5  <2> add[t3] sK/2 
# 6  <#> gv[*a] s 
# 7  <1> rv2sv sKRM*/1 
# 8  <2> sassign sKS/2 
# 9  <@> lineseq KP 
# a  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 720 optree_concise.t:57) v:{ 
# 2  <$> gv(*b) s 
# 3  <1> rv2sv sK/1 
# 4  <$> const(IV 42) s 
# 5  <2> add[t1] sK/2 
# 6  <$> gv(*a) s 
# 7  <1> rv2sv sKRM*/1 
# 8  <2> sassign sKS/2 
# 9  <@> lineseq KP 
# a  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT

#################################
pass("B::Concise OPTION TESTS");

checkOptree ( name	=> '-base3 sticky-exec',
	      bcopts	=> '-base3',
	      code	=> sub{$a=$b+42},
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 706 optree_concise.t:82) v:{ 
# 2  <#> gv[*b] s 
# 10 <1> rv2sv sK/1 
# 11 <$> const[IV 42] s 
# 12 <2> add[t3] sK/2 
# 20 <#> gv[*a] s 
# 21 <1> rv2sv sKRM*/1 
# 22 <2> sassign sKS/2 
# 100 <@> lineseq KP 
# 101 <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 721 optree_concise.t:88) v:{ 
# 2  <$> gv(*b) s 
# 10 <1> rv2sv sK/1 
# 11 <$> const(IV 42) s 
# 12 <2> add[t1] sK/2 
# 20 <$> gv(*a) s 
# 21 <1> rv2sv sKRM*/1 
# 22 <2> sassign sKS/2 
# 100 <@> lineseq KP 
# 101 <1> leavesub[1 ref] K/REFC,1 
EONT_EONT

checkOptree ( name	=> 'sticky-base3, -basic over sticky-exec',
	      bcopts	=> '-basic',
	      code	=> sub{$a=$b+42},
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 101 <1> leavesub[1 ref] K/REFC,1 
# 100    <@> lineseq KP 
# 1        <;> nextstate(main 707 optree_concise.t:104) v:{ 
# 22       <2> sassign sKS/2 
# 12          <2> add[t3] sK/2 
# 10             <1> rv2sv sK/1 
# 2                 <#> gv[*b] s 
# 11             <$> const[IV 42] s 
# 21          <1> rv2sv sKRM*/1 
# 20             <#> gv[*a] s 
EOT_EOT
# 101 <1> leavesub[1 ref] K/REFC,1 
# 100    <@> lineseq KP 
# 1        <;> nextstate(main 722 optree_concise.t:110) v:{ 
# 22       <2> sassign sKS/2 
# 12          <2> add[t1] sK/2 
# 10             <1> rv2sv sK/1 
# 2                 <$> gv(*b) s 
# 11             <$> const(IV 42) s 
# 21          <1> rv2sv sKRM*/1 
# 20             <$> gv(*a) s 
EONT_EONT

checkOptree ( name	=> '-base4',
	      bcopts	=> [qw/ -basic -base4 /],
	      code	=> sub{$a=$b+42},
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 22 <1> leavesub[1 ref] K/REFC,1 
# 21    <@> lineseq KP 
# 1        <;> nextstate(main 708 optree_concise.t:132) v:{ 
# 20       <2> sassign sKS/2 
# 11          <2> add[t3] sK/2 
# 3              <1> rv2sv sK/1 
# 2                 <#> gv[*b] s 
# 10             <$> const[IV 42] s 
# 13          <1> rv2sv sKRM*/1 
# 12             <#> gv[*a] s 
EOT_EOT
# 22 <1> leavesub[1 ref] K/REFC,1 
# 21    <@> lineseq KP 
# 1        <;> nextstate(main 723 optree_concise.t:138) v:{ 
# 20       <2> sassign sKS/2 
# 11          <2> add[t1] sK/2 
# 3              <1> rv2sv sK/1 
# 2                 <$> gv(*b) s 
# 10             <$> const(IV 42) s 
# 13          <1> rv2sv sKRM*/1 
# 12             <$> gv(*a) s 
EONT_EONT

checkOptree ( name	=> "restore -base36 default",
	      bcopts	=> [qw/ -basic -base36 /],
	      code	=> sub{$a},
	      crossfail	=> 1,
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 5  <1> leavesub[1 ref] K/REFC,1 
# 4     <@> lineseq KP 
# 1        <;> nextstate(main 709 optree_concise.t:160) v 
# 3        <1> rv2sv sK/1 
# 2           <#> gv[*a] s 
EOT_EOT
# 5  <1> leavesub[1 ref] K/REFC,1 
# 4     <@> lineseq KP 
# 1        <;> nextstate(main 724 optree_concise.t:166) v 
# 3        <1> rv2sv sK/1 
# 2           <$> gv(*a) s 
EONT_EONT

checkOptree ( name	=> "terse basic",
	      bcopts	=> [qw/ -basic -terse /],
	      code	=> sub{$a},
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# UNOP (0x9a60a68) leavesub [1] 
#     LISTOP (0x9be1388) lineseq 
#         COP (0x9acea68) nextstate 
#         UNOP (0x9acea20) rv2sv 
#             PADOP (0x9bfaf10) gv  GV (0x9bdd8f4) *a 
EOT_EOT
# UNOP (0x9a60a68) leavesub [1] 
#     LISTOP (0x9be1388) lineseq 
#         COP (0x9acea68) nextstate 
#         UNOP (0x9acea20) rv2sv 
#             SVOP (0x9bfaf10) gv  GV (0x9bdd8f4) *a 
EONT_EONT

checkOptree ( name	=> "sticky-terse exec",
	      bcopts	=> [qw/ -exec /],
	      code	=> sub{$a},
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# COP (0x9a61080) nextstate 
# PADOP (0x9a61050) gv  GV (0x9bdd8f4) *a 
# UNOP (0x9a61068) rv2sv 
# LISTOP (0x9a610d8) lineseq 
# UNOP (0x9a610f0) leavesub [1] 
EOT_EOT
# COP (0x9a61080) nextstate 
# SVOP (0x9a61050) gv  GV (0x9bdd8f4) *a 
# UNOP (0x9a61068) rv2sv 
# LISTOP (0x9a610d8) lineseq 
# UNOP (0x9a610f0) leavesub [1] 
EONT_EONT

pass("OPTIONS IN CMDLINE MODE");

checkOptree ( name => 'cmdline invoke -basic works',
	      prog => 'sort @a',
	      errs => [ 'Useless use of sort in void context at -e line 1.',
			'Name "main::a" used only once: possible typo at -e line 1.',
			],
	      #bcopts	=> '-basic', # default
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 6  <@> leave[1 ref] vKP/REFC 
# 1     <0> enter 
# 2     <;> nextstate(main 1 -e:1) v:{ 
# 5     <@> sort vK 
# 4        <1> rv2av[t2] lK/1 
# 3           <#> gv[*a] s 
EOT_EOT
# 6  <@> leave[1 ref] vKP/REFC 
# 1     <0> enter 
# 2     <;> nextstate(main 1 -e:1) v:{ 
# 5     <@> sort vK 
# 4        <1> rv2av[t1] lK/1 
# 3           <$> gv(*a) s 
EONT_EONT

checkOptree ( name => 'cmdline invoke -exec works',
	      prog => 'sort @a',
	      errs => [ 'Useless use of sort in void context at -e line 1.',
			'Name "main::a" used only once: possible typo at -e line 1.',
			],
	      bcopts => '-postorder',
	      strip_open_hints => 1,
	      expect => <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <0> enter 
# 2  <;> nextstate(main 1 -e:1) v:{ 
# 3  <#> gv[*a] s 
# 4  <1> rv2av[t2] lK/1 
# 5  <@> sort vK 
# 6  <@> leave[1 ref] vKP/REFC 
EOT_EOT
# 1  <0> enter 
# 2  <;> nextstate(main 1 -e:1) v:{ 
# 3  <$> gv(*a) s 
# 4  <1> rv2av[t1] lK/1 
# 5  <@> sort vK 
# 6  <@> leave[1 ref] vKP/REFC 
EONT_EONT

;

checkOptree
    ( name	=> 'cmdline self-strict compile err using prog',
      prog	=> 'use strict; sort @a',
      bcopts	=> [qw/ -basic -concise -exec /],
      errs	=> 'Global symbol "@a" requires explicit package name at -e line 1.',
      expect	=> 'nextstate',
      expect_nt	=> 'nextstate',
      noanchors => 1, # allow simple expectations to work
      );

checkOptree
    ( name	=> 'cmdline self-strict compile err using code',
      code	=> 'use strict; sort @a',
      bcopts	=> [qw/ -basic -concise -exec /],
      errs	=> qr/Global symbol "\@a" requires explicit package name at .*? line 1\./,
      note	=> 'this test relys on a kludge which copies $@ to rendering when empty',
      expect	=> 'Global symbol',
      expect_nt	=> 'Global symbol',
      noanchors => 1, # allow simple expectations to work
      );

checkOptree
    ( name	=> 'cmdline -basic -concise -exec works',
      prog	=> 'our @a; sort @a',
      bcopts	=> [qw/ -basic -concise -postorder /],
      errs	=> ['Useless use of sort in void context at -e line 1.'],
      strip_open_hints => 1,
      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <0> enter 
# 2  <;> nextstate(main 1 -e:1) v:{ 
# 3  <#> gv[*a] s 
# 4  <1> rv2av[t3] vK/OURINTR,1 
# 5  <;> nextstate(main 2 -e:1) v:{ 
# 6  <#> gv[*a] s 
# 7  <1> rv2av[t5] lK/1 
# 8  <@> sort vK 
# 9  <@> leave[1 ref] vKP/REFC 
EOT_EOT
# 1  <0> enter 
# 2  <;> nextstate(main 1 -e:1) v:{ 
# 3  <$> gv(*a) s 
# 4  <1> rv2av[t2] vK/OURINTR,1 
# 5  <;> nextstate(main 2 -e:1) v:{ 
# 6  <$> gv(*a) s 
# 7  <1> rv2av[t3] lK/1 
# 8  <@> sort vK 
# 9  <@> leave[1 ref] vKP/REFC 
EONT_EONT


#################################
pass("B::Concise STYLE/CALLBACK TESTS");

use B::Concise qw( walk_output add_style set_style_standard add_callback );

# new relative style, added by set_up_relative_test()
@stylespec =
    ( "#hyphseq2 (*(   (x( ;)x))*)<#classsym> "
      . "#exname#arg(?([#targarglife])?)~#flags(?(/#privateb)?)(x(;~->#next)x) "
      . "(x(;~=> #extra)x)\n" # new 'variable' used here
      
      , "  (*(    )*)     goto #seq\n"
      , "(?(<#seq>)?)#exname#arg(?([#targarglife])?)"
      #. "(x(;~=> #extra)x)\n" # new 'variable' used here
      );

sub set_up_relative_test {
    # add a new style, and a callback which adds an 'extra' property

    add_style ( "relative"	=> @stylespec );
    #set_style_standard ( "relative" );

    add_callback
	( sub {
	    my ($h, $op, $format, $level, $style) = @_;

	    # callback marks up const ops
	    $h->{arg} .= ' CALLBACK' if $h->{name} eq 'const';
	    $h->{extra} = '';

	    if ($lastnext and $$lastnext != $$op) {
		$h->{goto} = ($h->{seq} eq '-')
		    ? 'unresolved' : $h->{seq};
	    }

	    # 2 style specific behaviors
	    if ($style eq 'relative') {
		$h->{extra} = 'RELATIVE';
		$h->{arg} .= ' RELATIVE' if $h->{name} eq 'leavesub';
	    }
	    elsif ($style eq 'scope') {
		# suppress printout entirely
		$$format="" unless grep { $h->{name} eq $_ } @scopeops;
	    }
	});
}

#################################
set_up_relative_test();
pass("set_up_relative_test, new callback installed");

checkOptree ( name	=> 'callback used, independent of style',
	      bcopts	=> [qw/ -concise -exec /],
	      code	=> sub{$a=$b+42},
	      strip_open_hints => 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 722 optree_concise.t:372) v:{ 
# 2  <#> gv[*b] s 
# 3  <1> rv2sv sK/1 
# 4  <$> const[IV 42] CALLBACK s 
# 5  <2> add[t3] sK/2 
# 6  <#> gv[*a] s 
# 7  <1> rv2sv sKRM*/1 
# 8  <2> sassign sKS/2 
# 9  <@> lineseq KP 
# a  <1> leavesub[1 ref] K/REFC,1 
EOT_EOT
# 1  <;> nextstate(main 737 optree_concise.t:377) v:{ 
# 2  <$> gv(*b) s 
# 3  <1> rv2sv sK/1 
# 4  <$> const(IV 42) CALLBACK s 
# 5  <2> add[t1] sK/2 
# 6  <$> gv(*a) s 
# 7  <1> rv2sv sKRM*/1 
# 8  <2> sassign sKS/2 
# 9  <@> lineseq KP 
# a  <1> leavesub[1 ref] K/REFC,1 
EONT_EONT

checkOptree ( name	=> "new 'relative' style, -exec mode",
	      bcopts	=> [qw/ -basic -relative /],
	      code	=> sub{$a=$b+42},
	      crossfail	=> 1,
	      #retry	=> 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# a  <1> leavesub RELATIVE[1 ref] K ->1 => RELATIVE
# 9     <@> lineseq KP ->1 => RELATIVE
# 1        <;> nextstate(main 723 optree_concise.t:396) v ->1 => RELATIVE
# 8        <2> sassign sKS ->1 => RELATIVE
# 5           <2> add[t3] sK ->1 => RELATIVE
# 3              <1> rv2sv sK ->1 => RELATIVE
# 2                 <#> gv[*b] s ->1 => RELATIVE
# 4              <$> const[IV 42] CALLBACK s ->1 => RELATIVE
# 7           <1> rv2sv sKRM* ->1 => RELATIVE
# 6              <#> gv[*a] s ->1 => RELATIVE
EOT_EOT
# a  <1> leavesub RELATIVE[1 ref] K ->1 => RELATIVE
# 9     <@> lineseq KP ->1 => RELATIVE
# 1        <;> nextstate(main 738 optree_concise.t:402) v ->1 => RELATIVE
# 8        <2> sassign sKS ->1 => RELATIVE
# 5           <2> add[t1] sK ->1 => RELATIVE
# 3              <1> rv2sv sK ->1 => RELATIVE
# 2                 <$> gv(*b) s ->1 => RELATIVE
# 4              <$> const(IV 42) CALLBACK s ->1 => RELATIVE
# 7           <1> rv2sv sKRM* ->1 => RELATIVE
# 6              <$> gv(*a) s ->1 => RELATIVE
EONT_EONT

checkOptree ( name	=> "both -exec -relative",
	      bcopts	=> [qw/ -exec -relative /],
	      code	=> sub{$a=$b+42},
	      crossfail	=> 1,
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 724 optree_concise.t:425) v ->1 => RELATIVE
# 2  <#> gv[*b] s ->1 => RELATIVE
# 3  <1> rv2sv sK ->1 => RELATIVE
# 4  <$> const[IV 42] CALLBACK s ->1 => RELATIVE
# 5  <2> add[t3] sK ->1 => RELATIVE
# 6  <#> gv[*a] s ->1 => RELATIVE
# 7  <1> rv2sv sKRM* ->1 => RELATIVE
# 8  <2> sassign sKS ->1 => RELATIVE
# 9  <@> lineseq KP ->1 => RELATIVE
# a  <1> leavesub RELATIVE[1 ref] K ->1 => RELATIVE
EOT_EOT
# 1  <;> nextstate(main 739 optree_concise.t:431) v ->1 => RELATIVE
# 2  <$> gv(*b) s ->1 => RELATIVE
# 3  <1> rv2sv sK ->1 => RELATIVE
# 4  <$> const(IV 42) CALLBACK s ->1 => RELATIVE
# 5  <2> add[t1] sK ->1 => RELATIVE
# 6  <$> gv(*a) s ->1 => RELATIVE
# 7  <1> rv2sv sKRM* ->1 => RELATIVE
# 8  <2> sassign sKS ->1 => RELATIVE
# 9  <@> lineseq KP ->1 => RELATIVE
# a  <1> leavesub RELATIVE[1 ref] K ->1 => RELATIVE
EONT_EONT

#################################

@scopeops = qw( leavesub enter leave nextstate );
add_style
	( 'scope'  # concise copy
	  , "#hyphseq2 (*(   (x( ;)x))*)<#classsym> "
	  . "#exname#arg(?([#targarglife])?)~#flags(?(/#private)?)(x(;~->#next)x) "
	  , "  (*(    )*)     goto #seq\n"
	  , "(?(<#seq>)?)#exname#arg(?([#targarglife])?)"
	 );

checkOptree ( name	=> "both -exec -scope",
	      bcopts	=> [qw/ -exec -scope /],
	      code	=> sub{$a=$b+42},
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# 1  <;> nextstate(main 725 optree_concise.t:458) v ->1 
# a  <1> leavesub[1 ref] K/REFC,1 ->1 
EOT_EOT
# 1  <;> nextstate(main 740 optree_concise.t:472) v ->1 
# a  <1> leavesub[1 ref] K/REFC,1 ->1 
EONT_EONT


checkOptree ( name	=> "both -basic -scope",
	      bcopts	=> [qw/ -basic -scope /],
	      code	=> sub{$a=$b+42},
	      expect	=> <<'EOT_EOT', expect_nt => <<'EONT_EONT');
# a  <1> leavesub[1 ref] K/REFC,1 ->1 
# 1        <;> nextstate(main 726 optree_concise.t:470) v ->1 
EOT_EOT
# a  <1> leavesub[1 ref] K/REFC,1 ->1 
# 1        <;> nextstate(main 741 optree_concise.t:484) v ->1 
EONT_EONT
