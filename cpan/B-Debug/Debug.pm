package B::Debug

our $VERSION = '1.05_02'

use B < qw(peekop class walkoptree walkoptree_exec
         main_start main_root cstring sv_undef @specialsv_name)

my %done_gv

sub _printop
    my $op = shift
    my $addr = $op->$ ?? $op->ppaddr !! ''
    $addr =~ s/^PL_ppaddr// if $addr
    return sprintf: "0x\%x \%s \%s", $op->$, $op->$ ?? (class: $op) !! '', $addr


sub B::OP::debug($op)
    printf: $^STDOUT, <<'EOT', (class: $op), $op->$, $op->ppaddr, (_printop: $op->next), (_printop: $op->sibling), $op->targ, $op->type
%s (0x%lx)
	op_ppaddr	%s
	op_next		%s
	op_sibling	%s
	op_targ		%d
	op_type		%d
EOT
    printf: $^STDOUT, <<'EOT', $op->opt
	op_opt		%d
EOT
    printf: $^STDOUT, <<'EOT', $op->flags, $op->private
	op_flags	%d
	op_private	%d
EOT


sub B::UNOP::debug($op)
    $op->B::OP::debug: 
    printf: $^STDOUT, "\top_first\t\%s\n", _printop: $op->first


sub B::BINOP::debug($op)
    $op->B::UNOP::debug: 
    printf: $^STDOUT, "\top_last \t\%s\n", _printop: $op->last


sub B::LOOP::debug($op)
    $op->B::BINOP::debug: 
    printf: $^STDOUT, <<'EOT', < (_printop: $op->redoop), (_printop: $op->nextop), _printop: $op->lastop
	op_redoop	%s
	op_nextop	%s
	op_lastop	%s
EOT


sub B::LOGOP::debug($op)
    $op->B::UNOP::debug: 
    printf: $^STDOUT, "\top_other\t\%s\n", _printop: $op->other


sub B::LISTOP::debug($op)
    $op->B::BINOP::debug: 
    printf: $^STDOUT, "\top_children\t\%d\n", $op->children


sub B::PMOP::debug($op)
    $op->B::LISTOP::debug: 
    printf: $^STDOUT, "\top_pmreplroot\t0x\%x\n", $op->pmreplroot->$
    printf: $^STDOUT, "\top_pmreplstart\t0x\%x\n", $op->pmreplstart->$
    printf: $^STDOUT, "\top_pmstash\t\%s\n", < cstring:  <$op->pmstash
    printf: $^STDOUT, "\top_precomp->precomp\t\%s\n", < cstring:  <$op->precomp
    printf: $^STDOUT, "\top_pmflags\t0x\%x\n", < $op->pmflags
    printf: $^STDOUT, "\top_reflags\t0x\%x\n", < $op->reflags
    $op->pmreplroot->debug


sub B::COP::debug($op)
    $op->B::OP::debug: 
    my $cop_io = (class: $op->io) eq 'SPECIAL' ?? '' !! $op->io->as_string
    printf: $^STDOUT, <<'EOT', $op->label, $op->stashpv, $op->cop_seq, $op->warnings->$, cstring: $cop_io
	cop_label	"%s"
	cop_stashpv	"%s"
	cop_seq		%d
	cop_warnings	0x%x
	cop_io		%s
EOT


sub B::SVOP::debug($op)
    $op->B::OP::debug: 
    printf: $^STDOUT, "\top_sv\t\t0x\%x\n", $op->sv->$
    $op->sv->debug


sub B::PVOP::debug($op)
    $op->B::OP::debug: 
    printf: $^STDOUT, "\top_pv\t\t\%s\n", < cstring:  <$op->pv


sub B::PADOP::debug($op)
    $op->B::OP::debug: 
    printf: $^STDOUT, "\top_padix\t\%ld\n", < $op->padix


sub B::NULL::debug($sv)
    if ($sv->$ == (sv_undef: )->$)
        print: $^STDOUT, "&sv_undef\n"
    else
        printf: $^STDOUT, "NULL (0x\%x)\n", $sv->$
    


sub B::SV::debug($sv)
    if (!$sv->$)
        print: $^STDOUT, < (class: $sv), " = NULL\n"
        return
    
    printf: $^STDOUT, <<'EOT', < (class: $sv), $sv->$, < $sv->REFCNT, < $sv->FLAGS
%s (0x%x)
	REFCNT		%d
	FLAGS		0x%x
EOT


sub B::RV::debug($rv)
    B::SV::debug: $rv
    printf: $^STDOUT, <<'EOT', $rv->RV->$
	RV		0x%x
EOT
    $rv->RV->debug


sub B::PV::debug($sv)
    $sv->B::SV::debug: 
    my $pv = $sv->PV
    printf: $^STDOUT, <<'EOT', < (cstring: $pv), length: $pv
	xpv_pv		%s
	xpv_cur		%d
EOT


sub B::IV::debug($sv)
    $sv->B::SV::debug: 
    printf: $^STDOUT, "\txiv_iv\t\t\%d\n", < $sv->IV


sub B::NV::debug($sv)
    $sv->B::IV::debug: 
    printf: $^STDOUT, "\txnv_nv\t\t\%s\n", < $sv->NV


sub B::PVIV::debug($sv)
    $sv->B::PV::debug: 
    printf: $^STDOUT, "\txiv_iv\t\t\%d\n", < $sv->IV


sub B::PVNV::debug($sv)
    $sv->B::PVIV::debug: 
    printf: $^STDOUT, "\txnv_nv\t\t\%s\n", < $sv->NV


sub B::BM::debug($sv)
    $sv->B::PVNV::debug: 
    printf: $^STDOUT, "\txbm_useful\t\%d\n", < $sv->USEFUL
    printf: $^STDOUT, "\txbm_previous\t\%u\n", < $sv->PREVIOUS
    printf: $^STDOUT, "\txbm_rare\t\%s\n", < cstring: (chr: $sv->RARE)


sub B::CV::debug($sv)
    $sv->B::PVNV::debug: 
    my (@: $stash) =  $sv->STASH
    my (@: $start) =  $sv->START
    my (@: $root) =  $sv->ROOT
    my (@: $padlist) =  $sv->PADLIST
    my (@: $file) =  $sv->FILE
    my (@: $gv) =  $sv->GV
    printf: $^STDOUT, <<'EOT', $stash->$, $start->$, $root->$, $gv->$, $file, < $sv->DEPTH, $padlist, $sv->OUTSIDE->$, < $sv->OUTSIDE_SEQ
	STASH		0x%x
	START		0x%x
	ROOT		0x%x
	GV		0x%x
	FILE		%s
	DEPTH		%d
	PADLIST		0x%x
	OUTSIDE		0x%x
	OUTSIDE_SEQ	%d
EOT
    $start->debug if $start
    $root->debug if $root
    $gv->debug if $gv
    $padlist->debug if $padlist


sub B::AV::debug($av)
    $av->B::SV::debug: 
    my @array = $av->ARRAY
    print: $^STDOUT, "\tARRAY\t\t(", (join: ", ", (map:  {"0x" . $_->$ }, @array)), ")\n"
    printf: $^STDOUT, <<'EOT', (scalar: nelems @array), < $av->MAX, < $av->OFF
	FILL		%d
	MAX		%d
	OFF		%d
EOT


sub B::GV::debug($gv)
    if (%done_gv{+$gv->$}++)
        printf: $^STDOUT, "GV \%s::\%s\n", < $gv->STASH->NAME, < $gv->SAFENAME
        return
    
    my (@: $sv) =  $gv->SV
    my (@: $av) =  $gv->AV
    my (@: $cv) =  $gv->CV
        $gv->B::SV::debug: 
    printf: $^STDOUT, <<'EOT', < $gv->SAFENAME, < $gv->STASH->NAME, < $gv->STASH, $sv->$, < $gv->GvREFCNT, < $gv->FORM, $av->$, $gv->HV->$, $gv->EGV->$, $cv->$, < $gv->CVGEN, < $gv->LINE, < $gv->FILE, < $gv->GvFLAGS
	NAME		%s
	STASH		%s (0x%x)
	SV		0x%x
	GvREFCNT	%d
	FORM		0x%x
	AV		0x%x
	HV		0x%x
	EGV		0x%x
	CV		0x%x
	CVGEN		%d
	LINE		%d
	FILE		%s
	GvFLAGS		0x%x
EOT
    $sv->debug if $sv
    $av->debug if $av
    $cv->debug if $cv


sub B::SPECIAL::debug
    my $sv = shift
    print: $^STDOUT, @specialsv_name[$sv->$], "\n"


sub compile
    my $order = shift
    (B::clearsym: )
    if ($order && $order eq "exec")
        return sub (@< @_) { (walkoptree_exec: (main_start: ), "debug") }
    else
        return sub (@< @_) { (walkoptree: (main_root: ), "debug") }
    


1

__END__

=head1 NAME

B::Debug - Walk Perl syntax tree, printing debug info about ops

=head1 SYNOPSIS

	perl -MO=Debug[,OPTIONS] foo.pl

=head1 DESCRIPTION

See F<ext/B/README> and the newer L<B::Concise>, L<B::Terse>.

=head1 OPTIONS

With option -exec, walks tree in execute order,
otherwise in basic order.

=head1 AUTHOR

Malcolm Beattie, C<mbeattie@sable.ox.ac.uk>

=cut
