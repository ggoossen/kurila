#!./perl

use Pod::Plainer
my $parser = Pod::Plainer->new
my $header = "=pod\n\n"
my $input  = 'plnr_in.pod'
my $output = 'plnr_out.pod'

my $test = 0
print: $^STDOUT, "1..7\n"
while( ~< $^DATA )
    my $expected = $header. ~< $^DATA

    open: my $in, '>', $input or die: $^OS_ERROR
    print: $in, $header, $_
    close $in or die: $^OS_ERROR

    open: $in, '<', $input or die: $^OS_ERROR
    open: my $out, '>', $output or die: $^OS_ERROR
    $parser->parse_from_filehandle: $in, $out

    open: $out, '<', $output or die: $^OS_ERROR
    my $returned; do { local $^INPUT_RECORD_SEPARATOR = undef; $returned = ~< $out; }

    unless( $returned eq $expected )
        print: $^STDOUT, < map: { s/^/\#/mg; $_; },
                                    map: { $: $_ },               # to avoid readonly values
                                             @:                    "EXPECTED:\n", $expected, "GOT:\n", $returned
        print: $^STDOUT, "not "
    
    printf: $^STDOUT, "ok \%d\n", ++$test
    close $out
    close $in

END 
    1 while unlink: $input
    1 while unlink: $output


__END__
=head <> now reads in records
=head E<lt>E<gt> now reads in records
=item C<-T> and C<-B> not implemented on filehandles
=item C<-T> and C<-B> not implemented on filehandles
e.g. C<< Foo->bar() >> or C<< $obj->bar() >>
e.g. C<Foo-E<gt>bar()> or C<$obj-E<gt>bar()>
The C<< => >> operator is mostly just a more visually distinctive
The C<=E<gt>> operator is mostly just a more visually distinctive
C<uv < 0x80> in which case you can use C<*s = uv>.
C<uv E<lt> 0x80> in which case you can use C<*s = uv>.
C<time ^ ($$ + ($$ << 15))>), but that isn't necessary any more.
C<time ^ ($$ + ($$ E<lt>E<lt> 15))>), but that isn't necessary any more.
The bitwise operation C<<< >> >>>
The bitwise operation C<E<gt>E<gt>>
