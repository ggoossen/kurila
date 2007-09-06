#!./perl -w
# Test -DDEBUGGING things (in dump.c)

BEGIN {
    require "./test.pl"; 
}

# skip all tests unless perl was compiled with -DDEBUGGING
BEGIN {
    require Config;
    if ($Config::Config{'ccflags'} !~ /-DDEBUGGING\b/) {
        print "1..0 # Skip -- Perl built w/o -DDEBUGGING\n";
        exit 0;
    }
}

plan(tests => 1);

my $result = runperl( prog	=> 'print "foo"',
		       args	=> [ '-Dx' ],
		       stderr	=> 1,
		       );

my $refdump = <<'EO_DX_OUT';
{
1   TYPE = leave  ===> DONE
    TARG = 1
    FLAGS = (VOID,KIDS,PARENS)
    PRIVATE = (REFCOUNTED)
    REFCNT = 1
    {
2       TYPE = enter  ===> 3
    }
    {
3       TYPE = nextstate  ===> 4
        FLAGS = (VOID)
        LINE = 1
        PACKAGE = "main"
    }
    {
6       TYPE = print  ===> 1
        FLAGS = (VOID,KIDS)
        {
4           TYPE = pushmark  ===> 5
            FLAGS = (SCALAR)
        }
        {
5           TYPE = const  ===> 6
            FLAGS = (SCALAR)
            SV = PV("foo"\0)
        }
    }
}
EO_DX_OUT

# escape the regex chars in the reference dump
$refdump =~ s/([{}()\\])/\\$1/gms;

my $qr = qr/$refdump/;
# diag($qr);

like($result, qr/$qr/ms, "-Dx yields");

