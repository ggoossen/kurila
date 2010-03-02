BEGIN 
    use File::Basename
    my $THISDIR = dirname: $^PROGRAM_NAME
    unshift: $^INCLUDE_PATH, $THISDIR
    require "testp2pt.pl"
    TestPodIncPlainText->import


my %options = %+: map: { %: $_ => 1 }, @ARGV   ## convert cmdline to options-hash
my $passed  = testpodplaintext: \%options, $^PROGRAM_NAME
exit:  ($passed == 1) ?? 0 !! -1   unless env::var: 'HARNESS_ACTIVE'


__END__


=head1 Test nested item lists

This is a test to ensure the nested =item paragraphs
get indented appropriately.

=over 2

=item 1

First section.

=over 2

=item a

this is item a

=item b

this is item b

=back

=item 2

Second section.

=over 2

=item a

this is item a

=item b

this is item b

=item c

=item d

This is item c & d.

=back

=back

=cut
