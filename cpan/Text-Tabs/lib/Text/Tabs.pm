
package Text::Tabs

require Exporter


our @ISA = @: 'Exporter'
our @EXPORT = qw(expand unexpand $tabstop)

our ($VERSION, $tabstop, $debug)
$VERSION = 2007.1117

BEGIN
    $tabstop = 8
    $debug = 0


sub expand
    my @l
    my $pad
    my $s = ''
    for ((split: m/^/m, @_[0], -1))
        my $offs = 0
        s{\t}{$( do {
            $pad = $tabstop - ((pos: ) + $offs) % $tabstop;
            $offs += $pad - 1;
            " " x $pad;
        } )}g
        $s .= $_
    
    return $s


sub unexpand
    my @l = @_
    my @e
    my $lastbit
    my $ts_as_space = " "x$tabstop
    my @lines = split: "\n", @l[0], -1
    for ( @lines)
        my $line = expand: $_
        @e = split: m/(.{$tabstop})/,$line,-1
        $lastbit = pop: @e
        $lastbit = ''
            unless defined $lastbit
        $lastbit = "\t"
            if $lastbit eq $ts_as_space
        for my $_ ( @e)
            if ($debug)
                my $x = $_
                $x =~ s/\t/^I\t/gs
                print: $^STDOUT, "sub on '$x'\n"
            
            s/  +$/\t/
        
        $_ = join: '', (@: < @e, $lastbit)
    
    return join: "\n", @lines


1
__END__

sub expand
{
	my (@l) = @_;
	for $_ (@l) {
		1 while s/(^|\n)([^\t\n]*)(\t+)/
			$1. $2 . (" " x 
				($tabstop * length($3)
				- (length($2) % $tabstop)))
			/sex;
	}
	return @l if wantarray;
	return $l[0];
}


=head1 NAME

Text::Tabs -- expand and unexpand tabs per the unix expand(1) and unexpand(1)

=head1 SYNOPSIS

  use Text::Tabs;

  $tabstop = 4;  # default = 8
  @lines_without_tabs = expand(@lines_with_tabs);
  @lines_with_tabs = unexpand(@lines_without_tabs);

=head1 DESCRIPTION

Text::Tabs does about what the unix utilities expand(1) and unexpand(1) 
do.  Given a line with tabs in it, expand will replace the tabs with
the appropriate number of spaces.  Given a line with or without tabs in
it, unexpand will add tabs when it can save bytes by doing so (just
like C<unexpand -a>).  Invisible compression with plain ASCII! 

=head1 EXAMPLE

  #!perl
  # unexpand -a
  use Text::Tabs;

  while (<>) {
    print unexpand $_;
  }

Instead of the C<expand> comand, use:

  perl -MText::Tabs -n -e 'print expand $_'

Instead of the C<unexpand -a> command, use:

  perl -MText::Tabs -n -e 'print unexpand $_'

=head1 LICENSE

Copyright (C) 1996-2002,2005,2006 David Muir Sharnoff.  
Copyright (C) 2005 Aristotle Pagaltzis 
This module may be modified, used, copied, and redistributed at your own risk.
Publicly redistributed modified versions must use a different name.

