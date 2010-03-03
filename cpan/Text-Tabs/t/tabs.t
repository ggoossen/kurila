#!/usr/old/bin/perl5.004_01 -w

our @tests = split(m/\nEND\n/s, <<DONE);
TEST 1 u
                x
END
		x
END
TEST 2 e
		x
END
                x
END
TEST 3 e
	x
		y
			z
END
        x
                y
                        z
END
TEST 4 u
        x
                y
                        z
END
	x
		y
			z
END
TEST 5 u
This    Is      a       test    of      a       line with many embedded tabs
END
This	Is	a	test	of	a	line with many embedded tabs
END
TEST 6 e
This	Is	a	test	of	a	line with many embedded tabs
END
This    Is      a       test    of      a       line with many embedded tabs
END
TEST 7 u
            x
END
	    x
END
TEST 8 e
	
		
   	

           
END
        
                
        

           
END
TEST 9 u
           
END
	   
END
TEST 10 u
	
		
   	

           
END
	
		
	

	   
END
TEST 11 u
foobar                  IN	A		140.174.82.12

END
foobar			IN	A		140.174.82.12

END
DONE

use Test::More;

my $numtests = (nelems: @tests) / 2;
plan tests => $numtests;

use Text::Tabs;

my $rerun = env::var('PERL_DL_NONLAZY') ?? 0 !! 1;

while (@tests) {
        my $in = shift(@tests);
        my $out = shift(@tests);

        $in =~ s/^TEST\s*(\d+)?\s*(\S+)?\n//;

        my ($f, $fn);
        if ($2 eq 'e') {
                $f = \&expand;
                $fn = 'expand';
        } else {
                $f = \&unexpand;
                $fn = 'unexpand';
        }

        my $back = $f->($in);

        is($back, $out);
}
