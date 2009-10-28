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

Try out I<LOTS> of different ways of specifying references:

Reference the L<manpage/section>

Reference the L<manpage / section>

Reference the L<manpage/ section>

Reference the L<manpage /section>

Reference the L<"manpage/section">

Reference the L<"manpage"/section>

Reference the L<manpage/"section">

Reference the L<manpage/
section>

Reference the L<manpage
/section>

Now try it using the new "|" stuff ...

Reference the L<thistext|manpage/section>

Reference the L<thistext | manpage / section>

Reference the L<thistext| manpage/ section>

Reference the L<thistext |manpage /section>

Reference the L<thistext|
"manpage/section">

Reference the L<thistext
|"manpage"/section>

Reference the L<thistext|manpage/"section">

Reference the L<thistext|
manpage/
section>

Reference the L<thistext
|manpage
/section>

