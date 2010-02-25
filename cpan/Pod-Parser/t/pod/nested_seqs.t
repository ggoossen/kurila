BEGIN 
    use File::Basename
    my $THISDIR = dirname: $^PROGRAM_NAME
    unshift: $^INCLUDE_PATH, $THISDIR
    require "testp2pt.pl"
    TestPodIncPlainText->import: 


my %options = %+: map: { %: $_ => 1 }, @ARGV   ## convert cmdline to options-hash
my $passed  = testpodplaintext: \%options, $^PROGRAM_NAME
exit:  ($passed == 1) ?? 0 !! -1   unless env::var: 'HARNESS_ACTIVE'


__END__


=pod

The statement: C<This is dog kind's I<finest> hour!> is a parody of a
quotation from Winston Churchill.

=cut

