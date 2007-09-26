#!./perl
#use re 'debug';
BEGIN {
    ${^RE_TRIE_MAXBUFF}=-1;
    #${^RE_DEBUG_FLAGS}=0;
}

our $qr = 1;
for my $file ('./op/regexp.t', './t/op/regexp.t', ':op:regexp.t') {
    if (-r $file) {
	do $file or die $@;
	exit;
    }
}
die "Cannot find ./op/regexp.t or ./t/op/regexp.t\n";
