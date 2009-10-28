# IO::Dir.pm
#
# Copyright (c) 1997-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package IO::Dir


use Carp
use Symbol
use Exporter
use IO::File
our(@ISA, $VERSION, @EXPORT_OK)
use Tie::Hash
use File::stat
use File::Spec

@ISA = qw(Exporter)
$VERSION = "1.06"
$VERSION = eval $VERSION
@EXPORT_OK = qw(DIR_UNLINK)

sub DIR_UNLINK () { 1 }

sub new
    (nelems: @_) +>= 1 && (nelems @_) +<= 2 or croak: 'usage: new IO::Dir [DIRNAME]'
    my $class = shift
    my $dh = (gensym: )
    if ((nelems @_))
        IO::Dir::open: $dh, @_[0]
            or return undef
    
    bless: $dh, $class


sub DESTROY($dh)
    no warnings 'io'
    closedir: $dh

sub open($dh, $dirname)
    return undef
        unless opendir: $dh, $dirname
    # a dir name should always have a ":" in it; assume dirname is
    # in current directory
    $dirname = ':' .  $dirname if ( ($^OS_NAME eq 'MacOS') && ($dirname !~ m/:/) )
    $dh->*->{+io_dir_path} = $dirname
    1


sub close($dh)
    closedir: $dh


sub read($dh)
    readdir: $dh


sub read_all($dh)
    return @:  readdir: $dh 


sub seek($dh,$pos)
    seekdir: $dh,$pos


sub tell($dh)
    telldir: $dh


sub rewind($dh)
    rewinddir: $dh


1

__END__

=head1 NAME 

IO::Dir - supply object methods for directory handles

=head1 SYNOPSIS

    use IO::Dir;
    $d = IO::Dir->new(".");
    if (defined $d) {
        while (defined($_ = $d->read)) { something($_); }
        $d->rewind;
        while (defined($_ = $d->read)) { something_else($_); }
        undef $d;
    }

    tie %dir, 'IO::Dir', ".";
    foreach (keys %dir) {
	print $_, " " , $dir{$_}->size,"\n";
    }

=head1 DESCRIPTION

The C<IO::Dir> package provides two interfaces to perl's directory reading
routines.

The first interface is an object approach. C<IO::Dir> provides an object
constructor and methods, which are just wrappers around perl's built in
directory reading routines.

=over 4

=item new ( [ DIRNAME ] )

C<new> is the constructor for C<IO::Dir> objects. It accepts one optional
argument which,  if given, C<new> will pass to C<open>

=back

The following methods are wrappers for the directory related functions built
into perl (the trailing `dir' has been removed from the names). See L<perlfunc>
for details of these functions.

=over 4

=item open ( DIRNAME )

=item read ()

=item seek ( POS )

=item tell ()

=item rewind ()

=item close ()

=back

=head1 SEE ALSO

L<File::stat>

=head1 AUTHOR

Graham Barr. Currently maintained by the Perl Porters.  Please report all
bugs to <perl5-porters@perl.org>.

=head1 COPYRIGHT

Copyright (c) 1997-2003 Graham Barr <gbarr@pobox.com>. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
