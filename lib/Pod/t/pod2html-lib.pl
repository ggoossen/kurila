require Cwd
require Pod::Html
use Config < qw(config_value)
use File::Spec::Functions

sub convert_n_test($podfile, $testname)

    my $cwd = (Cwd::cwd: )
    my $base_dir = catdir: $cwd, (updir: ), "lib", "Pod"
    my $new_dir  = catdir: $base_dir, "t"
    my $infile   = catfile: $new_dir, "$podfile.pod"
    my $outfile  = catfile: $new_dir, "$podfile.html"

    Pod::Html::pod2html: 
        "--podpath=t"
        "--podroot=$base_dir"
        "--htmlroot=/"
        "--infile=$infile"
        "--outfile=$outfile"
        


    my ($expect, $result)
    do
        local $^INPUT_RECORD_SEPARATOR = undef
        # expected
        $expect = ~< $^DATA
        $expect =~ s/\[PERLADMIN\]/$((config_value: 'perladmin'))/

        # result
        open: my $in, "<", $outfile or die: "cannot open $outfile: $^OS_ERROR"
        $result = ~< $in
        close $in
    

    ok: $expect eq $result, $testname or do
        my $diff = '/bin/diff'
        -x $diff or $diff = '/usr/bin/diff'
        if (-x $diff)
            my $expectfile = "pod2html-lib.tmp"
            open: my $tmpfile, ">", $expectfile or die: $^OS_ERROR
            print: $tmpfile, $expect
            close $tmpfile
            my $diffopt = $^OS_NAME eq 'linux' ?? 'u' !! 'c'
            open: my $diff, "-|", "diff -$diffopt $expectfile $outfile" or die: $^OS_ERROR
            (print: $^STDOUT, "# $_") while ~< $diff
            close $diff
            unlink: $expectfile
        
    

    # pod2html creates these
    1 while unlink: $outfile
    1 while unlink: "pod2htmd.tmp"
    1 while unlink: "pod2htmi.tmp"


1
