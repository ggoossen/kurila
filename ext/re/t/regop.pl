use re Debug=> <qw(DUMP EXECUTE OFFSETS TRIEC)
my @tests=@:
    XY     =>  'X(A|[B]Q||C|D)Y'
    foobar =>  '[f][o][o][b][a][r]'
    x  =>  '.[XY].'
    'ABCD' => '(?:ABCP|ABCG|ABCE|ABCB|ABCA|ABCD)'
    'D:\dev/perl/ver/28321_/perl.exe'=>
    'm/(\.COM|\.EXE|\.BAT|\.CMD|\.VBS|\.VBE|\.JS|\.JSE|\.WSF|\.WSH|\.pyo|\.pyc|\.pyw|\.py)$/i'
    'q'=>'[q]'
    
while ((nelems @tests))
    my (@: $str,$pat)=@: splice: @tests,0,2
    print: $^STDERR, "\n"
    $pat="m/$pat/" if (substr: $pat,0,2) ne 'm/'
    # string eval to get the free regex message in the right place.
    eval qq[
        print: \$^STDERR, "$str"=~$pat ?? '\%MATCHED\%' !! '\%FAILED\%',"\n";
    ]
    die: $^EVAL_ERROR if $^EVAL_ERROR

