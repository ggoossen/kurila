#!./perl
#use re 'debug';
BEGIN 
    $^RE_TRIE_MAXBUF=-1
#$^RE_DEBUG_FLAGS=0;


our $qr = 1
for my $file ((@: './re/regexp.t', './t/re/regexp.t', ':re:regexp.t'))
    if (-r $file)
        evalfile $file or die: $^EVAL_ERROR
        exit
    

die: "Cannot find ./re/regexp.t or ./t/re/regexp.t\n"
