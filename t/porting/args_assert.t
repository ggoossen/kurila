#!perl

use warnings

use Test::More 'no_plan'

# Fail for every PERL_ARGS_ASSERT* macro that was declared but not used.

my %declared
my %used

my $prefix = ''

unless (-d 't' && -f 'MANIFEST')
    # we'll assume that we are in t then.
    # All files are interal to perl, so Unix-style is sufficiently portable.
    $prefix = '../'

do
    my $proto = $prefix . 'proto.h'

    open: my $fh, '<', $proto or die: "Can't open $proto: $^OS_ERROR"

    while (~<$fh)
        %declared{+$1}++ if m/^#define\s+(PERL_ARGS_ASSERT[A-Za-z_]+)\s+/

cmp_ok: nkeys %declared, '+>', 0, 'Some macros were declared'

if (!@ARGV)
    my $manifest = $prefix . 'MANIFEST'
    open: my $fh, '<', $manifest or die: "Can't open $manifest: $^OS_ERROR"
    while (~<$fh)
        # *.c or */*.c
        push: @ARGV, $prefix . $1 if m!^((?:[^/]+/)?[^/]+(?:\.c|_i\.h))\t!

while (~< *ARGV)
    %used{+$1}++ if m/^\s+(PERL_ARGS_ASSERT_[A-Za-z_]+);?$/

my %unused

foreach (keys %declared)
    %unused{+$_}++ unless %used{?$_}

if (keys %unused)
    for ((sort: keys %unused))
        fail: "$_ is declared but not used"
else
    pass: 'Every PERL_ARGS_ASSERT* macro declared is used'
