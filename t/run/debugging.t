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
1   TYPE = root  ===> DONE
    TARG = 1
    LOCATION = -e 1 1 
    FLAGS = (UNKNOWN,KIDS)
    REFCNT = 1
    {
2       TYPE = leave  ===> DONE
        LOCATION = -e 1 1 
        FLAGS = (VOID,KIDS,PARENS)
        {
3           TYPE = enter  ===> 4
            LOCATION = -e 1 1 
        }
        {
4           TYPE = nextstate  ===> 5
            LOCATION = -e 1 1 
            FLAGS = (VOID)
            PACKAGE = "main"
        }
        {
11          TYPE = print  ===> 2
            LOCATION = -e 1 1 
            FLAGS = (VOID,KIDS)
            {
5               TYPE = pushmark  ===> 6
                LOCATION = -e 1 6 
                FLAGS = (SCALAR)
            }
            {
9               TYPE = rv2gv  ===> 10
                LOCATION = -e 1 6 
                FLAGS = (SCALAR,KIDS,SPECIAL)
                {
8                   TYPE = srefgen  ===> 9
                    LOCATION = -e 1 6 
                    FLAGS = (SCALAR,KIDS)
                    {
7                       TYPE = rv2gv  ===> 8
                        LOCATION = -e 1 8 
                        FLAGS = (SCALAR,KIDS,REF,MOD)
                        {
6                           TYPE = gv  ===> 7
                            LOCATION = -e 1 8 
                            FLAGS = (SCALAR)
                        }
                    }
                }
            }
            {
10              TYPE = const  ===> 11
                LOCATION = -e 1 22 
                FLAGS = (SCALAR)
                SV = PV("foo"\0) [UTF8 "foo"]
            }
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

