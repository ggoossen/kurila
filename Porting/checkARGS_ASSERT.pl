#!/usr/bin/perl -w


# Print out any PERL_ARGS_ASSERT* macro that was declared but not used.

my %declared;
my %used;

open my $fh, '<', 'proto.h' or die "Can't open proto.h: $^OS_ERROR";
while (~< $fh) {
    %declared{+$1}++ if m/^#define\s+(PERL_ARGS_ASSERT[A-Za-z_]+)\s+/;
}

if (!nelems @ARGV) {
    open my $fh, '<', 'MANIFEST' or die "Can't open MANIFEST: $^OS_ERROR";
    while (~<$fh) {
	# *.c or */*.c or *_i.h or */*_i.h
	push @ARGV, $1 if m!^((?:[^/]+/)?[^/]+(?:\.c|_i\.h))\t!;
    }
}

while (~< *ARGV) {
    %used{+$1}++ if m/^\s+(PERL_ARGS_ASSERT_[A-Za-z_]+);$/;
}

my %unused;

foreach (keys %declared) {
    %unused{+$_}++ unless %used{?$_};
}

print $^STDOUT, $_, "\n" foreach sort keys %unused;
