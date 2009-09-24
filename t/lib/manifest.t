#!./perl -w

# Test the well formed-ness of the MANIFEST file.
# For now, just test that it uses tabs not spaces after the name of the file.

use File::Spec
require './test.pl'

my $failed = 0

plan('no_plan')

my $manifest = File::Spec->catfile(File::Spec->updir(), 'MANIFEST')

open my $m, '<', $manifest or die "Can't open '$manifest': $^OS_ERROR"

while (~< $m)
    chomp
    next unless m/\s/
    my @: $file, $separator = @: m/^(\S+)(\s+)/
    isnt($file, undef, "Line $(iohandle::input_line_number($m)) doesn't start with a blank") or next
    if ($separator =~ m/^\t*$/)
        # It's all tabs
        next
    elsif ($separator =~ m/^[ ]*$/)
        # It's all spaces
        fail("Spaces in entry for $file")
        next
    elsif ($separator =~ m/\t/)
        fail("Mixed tabs and spaces in entry for $file")
    else
        fail("Odd whitespace in entry for $file")

close $m or die $^OS_ERROR

is($failed, 0, 'All lines are good')
