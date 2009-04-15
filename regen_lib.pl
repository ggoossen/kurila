#!/usr/bin/perl -w

our ($Is_W32, $Is_OS2, $Is_Cygwin, $Is_NetWare, $Needs_Write);
use Config; # Remember, this is running using an existing perl
use File::Compare;
use Symbol;

# Common functions needed by the regen scripts

$Is_W32 = $^OS_NAME eq 'MSWin32';
$Is_OS2 = $^OS_NAME eq 'os2';
$Is_Cygwin = $^OS_NAME eq 'cygwin';
$Is_NetWare = config_value('osname') eq 'NetWare';
if ($Is_NetWare) {
  $Is_W32 = 0;
}

$Needs_Write = $Is_OS2 || $Is_W32 || $Is_Cygwin || $Is_NetWare;

sub safer_unlink {
  my @names = @_;
  my $cnt = 0;

  foreach my $name ( @names) {
    next unless -e $name;
    chmod 0777, $name if $Needs_Write;
    ( CORE::unlink($name) and ++$cnt
      or warn "Couldn't unlink $name: $^OS_ERROR\n" );
  }
  return $cnt;
}

sub safer_rename_silent($from, $to) {

  # Some dosish systems can't rename over an existing file:
  safer_unlink $to;
  chmod 0600, $from if $Needs_Write;
  rename $from, $to;
}

sub rename_if_different($from, $to) {

  if (compare($from, $to) == 0) {
      warn "no changes between '$from' & '$to'\n";
      safer_unlink($from);
      return;
  }
  warn "changed '$from' to '$to'\n";
  safer_rename_silent($from, $to) or die "renaming $from to $to: $^OS_ERROR";
}

# Saf*er*, but not totally safe. And assumes always open for output.
sub safer_open {
    my $name = shift;
    my $fh = gensym;
    open $fh, ">", $name or die "Can't create $name: $^OS_ERROR";
    *{$fh}->{+SCALAR} = $name;
    binmode $fh;
    $fh;
}

sub safer_close {
    my $fh = shift;
    close $fh or die 'Error closing ' . *{$fh}->{?SCALAR} . ": $^OS_ERROR";
}

1;
