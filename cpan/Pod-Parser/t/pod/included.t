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


##------------------------------------------------------------
# This file is =included by "include.t"
#
# This text should NOT be in the resultant pod document
# because we havent seen an =xxx pod directive in this file!
##------------------------------------------------------------

=pod

This is the text of the included file named "included.t".
It should appear in the final pod document from pod2xxx

=cut

##------------------------------------------------------------
# This text should NOT be in the resultant pod document
# because it is *after* an =cut an no other pod directives
# proceed it!
##------------------------------------------------------------
