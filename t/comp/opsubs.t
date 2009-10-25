#!./perl

use TestInit

use warnings

$^OUTPUT_AUTOFLUSH++

=pod

Even if you have a C<sub q{}>, calling C<q()> will be parsed as the
C<q()> operator.  Calling C<&q()> or C<main::q()> gets you the function.
This test verifies this behavior for nine different operators.

=cut

#use Test::More tests => 36;
BEGIN { require "./test.pl" }

plan: tests => 23

sub m  { return "m-".shift }
sub q  { return "q-".shift }
sub qq { return "qq-".shift }
sub qr { return "qr-".shift }
sub qw { return "qw-".shift }
sub qx { return "qx-".shift }
sub s  { return "s-".shift }

# m operator
can_ok:  'main', "m" 
:SILENCE_WARNING do # Complains because $_ is undef
    no warnings
    isnt:  m('unqualified'), "m-unqualified", "m('unqualified') is oper" 

is:  (main::m: 'main'), "m-main", "main::m() is func" 
is:  (&m->& <: 'amper'), "m-amper", "&m() is func" 

# q operator
can_ok:  'main', "q" 
isnt:  q('unqualified'), "q-unqualified", "q('unqualified') is oper" 
is:  (main::q: 'main'), "q-main", "main::q() is func" 
is:  (&q->& <: 'amper'), "q-amper", "&q() is func" 

# qq operator
can_ok:  'main', "qq" 
isnt:  qq('unqualified'), "qq-unqualified", "qq('unqualified') is oper" 
is:  (main::qq: 'main'), "qq-main", "main::qq() is func" 
is:  (&qq->& <: 'amper'), "qq-amper", "&qq() is func" 

# qr operator
can_ok:  'main', "qr" 
isnt:  qr('unqualified'), "qr-unqualified", "qr('unqualified') is oper" 
is:  (main::qr: 'main'), "qr-main", "main::qr() is func" 
is:  (&qr->& <: 'amper'), "qr-amper", "&qr() is func" 

# qx operator
can_ok:  'main', "qx" 
is:  (main::qx: 'main'), "qx-main", "main::qx() is func" 
is:  (&qx->& <: 'amper'), "qx-amper", "&qx() is func" 

# s operator
can_ok:  'main', "s" 
eval "s('unqualified')"
like:  $^EVAL_ERROR->{?description}, qr/^statement end found where string delimeter expected/, "s('unqualified') doesn't work" 
is:  (main::s: 'main'), "s-main", "main::s() is func" 
is:  (&s->& <: 'amper'), "s-amper", "&s() is func" 

=pod

from irc://irc.perl.org/p5p 2004/08/12

 <kane-xs>  bug or feature?
 <purl>     You decide!!!!
 <kane-xs>  [kane@coke ~]$ perlc -le'sub y{1};y(1)'
 <kane-xs>  Transliteration replacement not terminated at -e line 1.
 <Nicholas> bug I think
 <kane-xs>  i'll perlbug
 <rgs>      feature
 <kane-xs>  smiles at rgs
 <kane-xs>  done
 <rgs>      will be closed at not a bug,
 <rgs>      like the previous reports of this one
 <Nicholas> feature being first class and second class keywords?
 <rgs>      you have similar ones with q, qq, qr, qx, tr, s and m
 <rgs>      one could say 1st class keywords, yes
 <rgs>      and I forgot qw
 <kane-xs>  hmm silly...
 <Nicholas> it's acutally operators, isn't it?
 <Nicholas> as in you can't call a subroutine with the same name as an
            operator unless you have the & ?
 <kane-xs>  or fqpn (fully qualified package name)
 <kane-xs>  main::y() works just fine
 <kane-xs>  as does &y; but not y()
 <Andy>     If that's a feature, then let's write a test that it continues
            to work like that.

=cut
