#!/usr/bin/perl -w

our ($Needs_Write)
use File::Compare
use Symbol

$Needs_Write = $^OS_NAME eq 'cygwin' || $^OS_NAME eq 'os2' || $^OS_NAME eq 'MSWin32'

sub safer_unlink
    my @names = @_
    my $cnt = 0

    foreach my $name ( @names)
        next unless -e $name
        chmod: 0777, $name if $Needs_Write
        ( CORE::unlink: $name and ++$cnt
          or warn: "Couldn't unlink $name: $^OS_ERROR\n" )
    
    return $cnt


sub safer_rename_silent($from, $to)

    # Some dosish systems can't rename over an existing file:
    safer_unlink: $to
    chmod: 0600, $from if $Needs_Write
    rename: $from, $to


sub rename_if_different($from, $to)

    if ((compare: $from, $to) == 0)
        warn: "no changes between '$from' & '$to'\n"
        safer_unlink: $from
        return
    
    warn: "changed '$from' to '$to'\n"
    safer_rename_silent: $from, $to or die: "renaming $from to $to: $^OS_ERROR"


# Saf*er*, but not totally safe. And assumes always open for output.
sub safer_open
    my $name = shift
    my $fh = (gensym: )
    open: $fh, ">", $name or die: "Can't create $name: $^OS_ERROR"
    $fh->*->{+SCALAR} = $name
    binmode: $fh
    $fh


sub safer_close
    my $fh = shift
    close $fh or die: 'Error closing ' . $fh->*->{?SCALAR} . ": $^OS_ERROR"


1
