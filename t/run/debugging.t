#!./perl -w
# Test -DDEBUGGING things (in dump.c)

BEGIN {
    require "./test.pl"; 
}

# skip all tests unless perl was compiled with -DDEBUGGING
BEGIN {
    require Config;
    if (Config::config_value('ccflags') !~ m/-DDEBUGGING\b/) {
        skip_all("Perl built w/o -DDEBUGGING");
    }
}

plan(tests => 1);

my $result = runperl( prog	=> 'print \*STDOUT, "foo"',
		       args	=> \@( '-Dx' ),
		       stderr	=> 1,
		       );

my $refdump = <<'EO_DX_OUT';
{
1   TYPE = leave  ===> DONE
    TARG = 1
    LOCATION = -e 1 1 
    FLAGS = (VOID,KIDS,PARENS)
    PRIVATE = (REFCOUNTED)
    REFCNT = 1
    {
2       TYPE = enter  ===> 3
        LOCATION = -e 1 1 
    }
    {
3       TYPE = nextstate  ===> 4
        LOCATION = -e 1 1 
        FLAGS = (VOID)
        PACKAGE = "main"
    }
    {
10      TYPE = print  ===> 1
        LOCATION = -e 1 1 
        FLAGS = (VOID,KIDS)
        {
4           TYPE = pushmark  ===> 5
            LOCATION = -e 1 6 
            FLAGS = (SCALAR)
        }
        {
8           TYPE = rv2gv  ===> 9
            LOCATION = -e 1 6 
            FLAGS = (SCALAR,KIDS,SPECIAL)
            {
7               TYPE = srefgen  ===> 8
                LOCATION = -e 1 6 
                FLAGS = (SCALAR,KIDS)
                {
6                   TYPE = rv2gv  ===> 7
                    LOCATION = -e 1 8 
                    FLAGS = (SCALAR,KIDS,REF,MOD)
                    {
5                       TYPE = gv  ===> 6
                        LOCATION = -e 1 8 
                        FLAGS = (SCALAR)
                    }
                }
            }
        }
        {
9           TYPE = const  ===> 10
            LOCATION = -e 1 22 
            FLAGS = (SCALAR)
            SV = PV("foo"\0) [UTF8 "foo"]
        }
    }
}
EO_DX_OUT

# escape the regex chars in the reference dump
$refdump =~ s/([{}()\\\[\]])/\\$1/gms;
$refdump =~ s/(.*)\@THR\n/$( Config::config_value("useithreads") ?? $1 . "\n" !! '' )/g;
$refdump =~ s/(.*)\@NO_THR\n/$( Config::config_value("useithreads") ?? '' !! $1."\n" )/g;

my $qr = qr/$refdump/;
# diag($qr);

like($result, qr/$qr/ms, "-Dx yields");

