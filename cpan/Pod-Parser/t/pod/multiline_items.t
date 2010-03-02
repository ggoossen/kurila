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


=head1 Test multiline item lists

This is a test to ensure that multiline =item paragraphs
get indented appropriately.

=over 4 

=item This 
is
a
test.

=back

=cut
