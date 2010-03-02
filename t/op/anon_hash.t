#!./perl

BEGIN { require "./test.pl"; }
plan:  tests => 16 

my $x = \ %:  aap => 'noot', Mies => 'Wim' 
is: $x->{?aap}, 'noot', "anon hash ref construction"
is: $x->{?Mies}, 'Wim', "anon hash ref construction"

is: (join: '*', (sort: @: < (%:  aap => 'noot', Mies => 'Wim' )))
    'Mies*Wim*aap*noot'
    "anon hash is list in list context"

is: (%: aap => 'noot', Mies => 'Wim'){aap}, 'noot', "using helem directy on anon hash"
is: (%: aap => 'noot'){aap}, 'noot', "using \%: hash constructor"

is:  %(:  aap => 'noot'){aap}, 'noot', "using \%(: hash constructor"

my $x = \ $%
is: (Internals::SvREFCNT: $x), 1, "there is only one reference"

eval_dies_like:  q| %(: aap => 'noot', Mies => 'Wim' )->{aap}; |
                 qr/Hash may not be used as a reference/
                 "anon hash as reference" 

do
    my $h = %:  aap => "noot", Mies => "Wim" 
    # OPf_ASSIGN
    my ($aap, $mies)
    (%:  aap => $aap, Mies => $mies ) = $h
    is:  $aap, "noot" 
    is:  $mies, "Wim" 

    (%:  aap => (@: $aap) ) = %: aap => @: "noot"
    is:  $aap, "noot" 

    # with an expansion
    my $rest
    (%:  aap => $aap, @< $rest ) = $h
    is:  (join: "*", $rest), "Mies*Wim"

    eval_dies_like: q|my ($rest, $aap, $h); %(: @< $rest, aap => $aap ) = $h|
                    qr/\Qarray expand must be the last item in anonymous hash (\E[%]:\) assignment/ 

    dies_like:  { (%:  aap => $aap ) = $h; }
                qr/\QGot extra value(s) in anonymous hash (\E[%]\Q:) assignment\E/ 

    # OPf_ASSIGN & OPf_ASSIGN_PART
    my (@: (%:  aap => $aap, Mies => $mies)) = @: $h
    is:  $aap, "noot" 
    is:  $mies, "Wim" 

