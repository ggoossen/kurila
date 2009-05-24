#!./perl

our $qr = 1
for my $file (@('./op/regexp.t', './t/op/regexp.t', ':op:regexp.t'))
    if (-r $file)
        evalfile $file or die $^EVAL_ERROR
        exit
    

die "Cannot find ./op/regexp.t or ./t/op/regexp.t\n"
