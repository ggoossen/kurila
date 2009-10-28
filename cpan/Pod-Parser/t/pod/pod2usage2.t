#!/usr/bin/perl -w

use Test::More
use warnings

BEGIN 
    if ($^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'VMS')
        plan: skip_all => "Not portable on Win32 or VMS\n"
    else
        plan: tests => 14
    

use Pod::Usage

sub getoutput
    my (@: $code) =  @_
    my $pid = open: my $in, "-|", "-"
    unless(defined $pid)
        die: "Cannot fork: $^OS_ERROR"
    
    if($pid)
        # parent
        my @out = @:  ~< $in 
        close: $in
        my $exit = $^CHILD_ERROR>>8
        for (@out)
            s/^/#/
        print: $^STDOUT, "#EXIT=$exit OUTPUT=+++#$((join: '',@out))#+++\n"
        return @: $exit, join: "", @out

    # child
    open: $^STDERR, ">&", $^STDOUT
    $code->& <:  < @_ 
    print: $^STDOUT, "--NORMAL-RETURN--\n"
    exit 0


sub compare($left,$right)
    $left  =~ s/^#\s+/#/gm
    $right =~ s/^#\s+/#/gm
    $left  =~ s/\s+/ /gm
    $right =~ s/\s+/ /gm
    return $left eq $right


my (@: $exit, $text) =  getoutput:  sub (@< @_) { (pod2usage: ) } 
is: $exit, 2,                 "Exit status pod2usage ()"
ok: (compare: $text, <<'EOT'), "Output test pod2usage ()"
#Usage:
#    frobnicate [ -r | --recursive ] [ -f | --force ] file ...
#
EOT

(@: $exit, $text) =  getoutput:  sub (@< @_) { (pod2usage: 
                                      message => 'You naughty person, what did you say?'
                                      verbose => 1 ) }
is: $exit, 1,                 "Exit status pod2usage (message => '...', verbose => 1)"
ok: (compare: $text, <<'EOT'), "Output test pod2usage (message => '...', verbose => 1)"
#You naughty person, what did you say?
# Usage:
#     frobnicate [ -r | --recursive ] [ -f | --force ] file ...
# 
# Options:
#     -r | --recursive
#         Run recursively.
# 
#     -f | --force
#         Just do it!
# 
#     -n number
#         Specify number of frobs, default is 42.
# 
EOT

(@: $exit, $text) =  getoutput:  sub (@< @_) { (pod2usage: 
                                         "-verbose" => 2, "-exit" => 42 ) } 
is: $exit, 42,                "Exit status pod2usage (verbose => 2, exit => 42)"
ok: (compare: $text, <<'EOT'), "Output test pod2usage (verbose => 2, exit => 42)"
#NAME
#     frobnicate - do what I mean
#
# SYNOPSIS
#     frobnicate [ -r | --recursive ] [ -f | --force ] file ...
#
# DESCRIPTION
#     frobnicate does foo and bar and what not.
#
# OPTIONS
#     -r | --recursive
#         Run recursively.
#
#     -f | --force
#         Just do it!
#
#     -n number
#         Specify number of frobs, default is 42.
#
EOT

(@: $exit, $text) =  getoutput:  sub (@< @_) { (pod2usage: 0) } 
is: $exit, 0,                 "Exit status pod2usage (0)"
ok: (compare: $text, <<'EOT'), "Output test pod2usage (0)"
#Usage:
#     frobnicate [ -r | --recursive ] [ -f | --force ] file ...
#
# Options:
#     -r | --recursive
#         Run recursively.
#
#     -f | --force
#         Just do it!
#
#     -n number
#         Specify number of frobs, default is 42.
#
EOT

(@: $exit, $text) =  getoutput:  sub (@< @_) { (pod2usage: 42) } 
is: $exit, 42,                "Exit status pod2usage (42)"
ok: (compare: $text, <<'EOT'), "Output test pod2usage (42)"
#Usage:
#     frobnicate [ -r | --recursive ] [ -f | --force ] file ...
#
EOT

(@: $exit, $text) =  getoutput:  sub (@< @_) { (pod2usage: verbose => 0, exit => 'NOEXIT') } 
is: $exit, 0,                 "Exit status pod2usage (verbose => 0, exit => 'NOEXIT')"
ok: (compare: $text, <<'EOT'), "Output test pod2usage (verbose => 0, exit => 'NOEXIT')"
#Usage:
#     frobnicate [ -r | --recursive ] [ -f | --force ] file ...
#
# --NORMAL-RETURN--
EOT

(@: $exit, $text) =  getoutput:  sub (@< @_) { (pod2usage: verbose => 99, sections => 'DESCRIPTION') } 
is: $exit, 1,                 "Exit status pod2usage (verbose => 99, sections => 'DESCRIPTION')"
ok: (compare: $text, <<'EOT'), "Output test pod2usage (verbose => 99, sections => 'DESCRIPTION')"
#Description:
#     frobnicate does foo and bar and what not.
#
EOT


__END__

=head1 NAME

frobnicate - do what I mean

=head1 SYNOPSIS

B<frobnicate> S<[ B<-r> | B<--recursive> ]> S<[ B<-f> | B<--force> ]>
  file ...

=head1 DESCRIPTION

B<frobnicate> does foo and bar and what not.

=head1 OPTIONS

=over 4

=item B<-r> | B<--recursive>

Run recursively.

=item B<-f> | B<--force>

Just do it!

=item B<-n> number

Specify number of frobs, default is 42.

=back

=cut

