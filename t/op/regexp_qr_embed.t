#!./perl

our $qr = 1;
our $qr_embed = 1;
for my $file ('./op/regexp.t', './t/op/regexp.t', ':op:regexp.t') {
    if (-r $file) {
	do $file or die $@;
	exit;
    }
}
die "Cannot find ./op/regexp.t or ./t/op/regexp.t\n";
