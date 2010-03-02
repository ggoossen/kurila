#!/usr/bin/perl
#
# t/pod-spelling.t -- Test POD spelling.

use Test::More

# Make sure we have prerequisites.  hunspell is currently not supported due to
# lack of support for contractions.
eval 'use Test::Pod 1.00'
plan: skip_all => "Test::Pod 1.00 required for testing POD" if $^EVAL_ERROR
eval 'use Pod::Spell'
plan: skip_all => "Pod::Spell required to test POD spelling" if $^EVAL_ERROR
my @spell
for my $dir ((split: ':', (env::var: 'PATH')))
    if (-x "$dir/ispell")
        @spell = @: "$dir/ispell", '-d', 'american', '-l'
    last if @spell

plan: skip_all => "ispell required to test POD spelling" unless @spell

# Run the test, one for each POD file.
my @pod = (all_pod_files: )
my $count = nelems @pod
print: "1..$count\n"
my $n = 1
for my $pod (@pod)
    my $child = open: my $child_fh, '-|'
    if (not defined $child)
        die: "Cannot fork: $^OS_ERROR\n"
    elsif ($child == 0)
        my $pid = (open: my $spell_fh, '|-', @spell) or die: "Cannot run @spell: $^OS_ERROR\n"
        open: my $pod_fh, '<', $pod or die: "Cannot open $pod: $^OS_ERROR\n"
        my $parser = Pod::Spell->new
        $parser->parse_from_filehandle : $pod_fh, $spell_fh
        close $pod_fh
        close $spell_fh
        exit: $^CHILD_ERROR >> 8
    else
        my @words = ~< $child_fh
        close $child_fh
        if ($^CHILD_ERROR != 0)
            print: "ok $n # skip - @spell failed\n"
        elsif (@words)
            for (@words)
                s/^\s+//
                s/\s+$//
            print: "not ok $n\n"
            print: " - Misspelled words found in $pod\n"
            print: "   @words\n"
        else
            print: "ok $n\n"
        $n++
