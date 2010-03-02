package B::Showlex

our $VERSION = '1.02'

use B < qw(svref_2object comppadlist class)
use B::Terse ()
use B::Concise ()

#
# Invoke as
#     perl -MO=Showlex,foo bar.pl
# to see the names of lexical variables used by &foo
# or as
#     perl -MO=Showlex bar.pl
# to see the names of file scope lexicals used by bar.pl
#


# borrowed from B::Concise
our $walkHandle = $^STDOUT

sub walk_output # updates $walkHandle
    $walkHandle = B::Concise::walk_output: < @_
    #print "got $walkHandle";
    #print $walkHandle "using it";
    $walkHandle


sub shownamearray($name, $av)
    my @els = $av->ARRAY
    my $count = (nelems @els)
    print: $walkHandle, "$name has $count entries\n"
    for my $i (B::PAD_NAME_START_INDEX .. $count -1)
        my $sv = @els[$i]
        if ((class: $sv) ne "SPECIAL")
            printf: $walkHandle, "$i: \%s (0x\%lx) \%s\n", (class: $sv), $sv->$, $sv->PVX_const
        else
            printf: $walkHandle, "$i: \%s\n", $sv->terse
        #printf $walkHandle "$i: \%s\n", B::Concise::concise_sv($sv);
        
    


sub showvaluearray($name, $av)
    my @els = $av->ARRAY
    my $count = (nelems @els)
    print: $walkHandle, "$name has $count entries\n"
    for my $i (0 .. $count -1 )
        printf: $walkHandle, "$i: \%s\n", @els[$i]->terse
    #print $walkHandle "$i: %s\n", B::Concise::concise_sv($els[$i]);
    


sub showlex($objname, $namesav, $valsav)
    shownamearray: "Pad of lexical names for $objname", $namesav
    showvaluearray: "Pad of lexical values for $objname", $valsav


my ($newlex, $nosp1) # rendering state vars

sub newlex($objname, $names, $vals)
    my @names = $names->ARRAY
    my @vals  = $vals->ARRAY
    my $count = (nelems @names)
    print: $walkHandle, "$objname Pad has $count entries\n"
    printf: $walkHandle, "0: \%s\n", @names[0]->terse unless $nosp1
    for my $i (1..$count -1)
        printf: $walkHandle, "$i: \%s = \%s\n", @names[$i]->terse, @vals[$i]->terse
            unless $nosp1 and @names[$i]->terse =~ m/SPECIAL/
    


sub showlex_obj($objname, $obj)
    $objname =~ s/^&main::/&/
    showlex: $objname, < (svref_2object: $obj)->PADLIST->ARRAY if !$newlex
    newlex: $objname, < (svref_2object: $obj)->PADLIST->ARRAY if  $newlex


sub showlex_main
    showlex: "comppadlist", < (comppadlist: )->ARRAY	if !$newlex
    newlex: "main", < (comppadlist: )->ARRAY		if  $newlex


sub compile
    my @options = grep: { (ref::svtype: $_) eq 'PLAINVALUE' && m/^-/ }, @_
    my @args = grep: { (ref::svtype: $_) ne 'PLAINVALUE' || !m/^-/ }, @_
    for my $o ( @options)
        $newlex = 1 if $o eq "-newlex"
        $nosp1  = 1 if $o eq "-nosp"

    return &showlex_main unless (nelems @args)
    return sub (@< @_)
        my $objref
        foreach my $objname ( @args)
            next unless $objname        # skip nulls w/o carping

            if ((ref: $objname))
                print: $walkHandle, "B::Showlex::compile($((dump::view: $objname)))\n"
                $objref = $objname
                $objname = dump::view: $objname
            elsif ((ref::svtype: $objname) ne 'PLAINVALUE')
                $objref = \ $: $objname
                $objname = dump::view: $objname
            else
                $objname = "main::$objname" unless $objname =~ m/::/
                print: $walkHandle, "$objname:\n"
                die: "err: unknown function ($objname)\n"
                    unless $objname->*{CODE}
                $objref = \$objname->&
            showlex_obj: $objname, $objref


1

__END__

=head1 NAME

B::Showlex - Show lexical variables used in functions or files

=head1 SYNOPSIS

        perl -MO=Showlex[,-OPTIONS][,SUBROUTINE] foo.pl

=head1 DESCRIPTION

When a comma-separated list of subroutine names is given as options, Showlex
prints the lexical variables used in those subroutines.  Otherwise, it prints
the file-scope lexicals in the file.

=head1 EXAMPLES

Traditional form:

 $ perl -MO=Showlex -e 'my ($i,$j,$k)=(1,"foo")'
 Pad of lexical names for comppadlist has 4 entries
 0: SPECIAL #1 &PL_sv_undef
 1: PVNV (0x9db0fb0) $i
 2: PVNV (0x9db0f38) $j
 3: PVNV (0x9db0f50) $k
 Pad of lexical values for comppadlist has 5 entries
 0: SPECIAL #1 &PL_sv_undef
 1: NULL (0x9da4234)
 2: NULL (0x9db0f2c)
 3: NULL (0x9db0f44)
 4: NULL (0x9da4264)
 -e syntax OK

New-style form:

 $ perl -MO=Showlex,-newlex -e 'my ($i,$j,$k)=(1,"foo")'
 main Pad has 4 entries
 0: SPECIAL #1 &PL_sv_undef
 1: PVNV (0xa0c4fb8) "$i" = NULL (0xa0b8234)
 2: PVNV (0xa0c4f40) "$j" = NULL (0xa0c4f34)
 3: PVNV (0xa0c4f58) "$k" = NULL (0xa0c4f4c)
 -e syntax OK

New form, no specials, outside O framework:

 $ perl -MB::Showlex -e \
    'my ($i,$j,$k)=(1,"foo"); B::Showlex::compile(-newlex,-nosp)->()'
 main Pad has 4 entries
 1: PVNV (0x998ffb0) "$i" = IV (0x9983234) 1
 2: PVNV (0x998ff68) "$j" = PV (0x998ff5c) "foo"
 3: PVNV (0x998ff80) "$k" = NULL (0x998ff74)

Note that this example shows the values of the lexicals, whereas the other
examples did not (as they're compile-time only).

=head2 OPTIONS

The C<-newlex> option produces a more readable C<< name => value >> format,
and is shown in the second example above.

The C<-nosp> option eliminates reporting of SPECIALs, such as C<0: SPECIAL
#1 &PL_sv_undef> above.  Reporting of SPECIALs can sometimes overwhelm
your declared lexicals.

=head1 SEE ALSO

C<B::Showlex> can also be used outside of the O framework, as in the third
example.  See C<B::Concise> for a fuller explanation of reasons.

=head1 TODO

Some of the reported info, such as hex addresses, is not particularly
valuable.  Other information would be more useful for the typical
programmer, such as line-numbers, pad-slot reuses, etc..  Given this,
-newlex isnt a particularly good flag-name.

=head1 AUTHOR

Malcolm Beattie, C<mbeattie@sable.ox.ac.uk>

=cut
