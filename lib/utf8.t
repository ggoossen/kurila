#!./perl 

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require './test.pl';
}

# NOTE!
#
# Think carefully before adding tests here.  In general this should be
# used only for about three categories of tests:
#
# (1) tests that absolutely require 'use utf8', and since that in general
#     shouldn't be needed as the utf8 is being obsoleted, this should
#     have rather few tests.  If you want to test Unicode and regexes,
#     you probably want to go to op/regexp or op/pat; if you want to test
#     split, go to op/split; pack, op/pack; appending or joining,
#     op/append or op/join, and so forth
#
# (2) tests that have to do with Unicode tokenizing (though it's likely
#     that all the other Unicode tests sprinkled around the t/**/*.t are
#     going to catch that)
#
# (3) complicated tests that simultaneously stress so many Unicode features
#     that deciding into which other test script the tests should go to
#     is hard -- maybe consider breaking up the complicated test
#
#

plan tests => 31;

{
    # bug id 20001009.001

    my ($a, $b);

    { use bytes; $a = "\xc3\xa4" }
    { use utf8;  $b = "\xe4"     }

    my $test = 68;

    ok($a ne $b);

    { use utf8; ok($a ne $b) }
}


{
    # bug id 20000730.004

    my $smiley = "\x{263a}";

    for my $s ("\x{263a}",
	       $smiley,
		
	       "" . $smiley,
	       "" . "\x{263a}",

	       $smiley    . "",
	       "\x{263a}" . "",
	       ) {
	my $length_chars = length($s);
	my $length_bytes;
	{ use bytes; $length_bytes = length($s) }
	my @regex_chars = $s =~ m/(.)/g;
	my $regex_chars = @regex_chars;
	my @split_chars = split //, $s;
	my $split_chars = @split_chars;
	ok("$length_chars/$regex_chars/$split_chars/$length_bytes" eq
	   "1/1/1/3");
    }

    for my $s ("\x{263a}" . "\x{263a}",
	       $smiley    . $smiley,

	       "\x{263a}\x{263a}",
	       "$smiley$smiley",
	       
	       "\x{263a}" x 2,
	       $smiley    x 2,
	       ) {
	my $length_chars = length($s);
	my $length_bytes;
	{ use bytes; $length_bytes = length($s) }
	my @regex_chars = $s =~ m/(.)/g;
	my $regex_chars = @regex_chars;
	my @split_chars = split //, $s;
	my $split_chars = @split_chars;
	ok("$length_chars/$regex_chars/$split_chars/$length_bytes" eq
	   "2/2/2/6");
    }
}


{
    my $w = 0;
    local $SIG{__WARN__} = sub { print "#($_[0])\n"; $w++ };
    my $x = eval q/"\\/ . "\x{100}" . q/"/;;
   
    ok($w == 0 && $x eq "\x{100}");
}

{
    use warnings;
    my $progfile = 'utf' . $$;
    END {unlink_all $progfile}

    # If I'm right 60 is '>' in ASCII, ' ' in EBCDIC
    # 173 is not punctuation in either ASCII or EBCDIC
    my (@char);
    foreach (60, 173, 257, 65532) {
      my $char = chr $_;
      utf8::encode($char);
      # I don't want to use map {ord} and I've no need to hardcode the UTF
      # version
      my $charsubst = $char;
      $charsubst =~ s/(.)/ord ($1) . ','/ge;
      chop $charsubst;
      push @char, [$_, $char, $charsubst];
    }
    foreach (
             ['check our detection program works',
              '@a = ("'.chr(60).'\x2A", ""); display @a', qr/^>60,42<><$/],
             ['check literal 8 bit input',
              '$a = "' . chr (173) . '"; display $a', qr/^>173<$/],
             ['check no utf8; makes no change',
              'no utf8; $a = "' . chr (173) . '"; display $a', qr/^>173<$/],
             # Now we do the real byte sequences that are valid UTF8
             (map {
               ["the utf8 sequence for chr $_->[0]",
                qq(\$a = "$_->[1]"; display \$a), qr/^>$_->[2]<$/],
               ["no utf8; for the utf8 sequence for chr $_->[0]",
                qq(no utf8; \$a = "$_->[1]"; display \$a), qr/^>$_->[2]<$/],
               ["use utf8; for the utf8 sequence for chr $_->[0]",
                qq(use utf8; \$a = "$_->[1]"; display \$a), qr/^>$_->[0]<$/],
              } @char),
             # Interpolation of hex characters needs to take place now, as we're
             # testing feeding malformed utf8 into perl. Bug now fixed was an
             # "out of memory" error. We really need the "" [rather than qq()
             # or q()] to get the best explosion.
             ["!Feed malformed utf8 into perl.", <<"BANG",
    use utf8; %a = ("\xE1\xA0"=>"sterling");
    print 'start'; printf '%x,', ord \$_ foreach keys %a; print "end\n";
BANG
	      qr/^Malformed UTF-8 character \(2 bytes, need 3\).*start\d+,end$/s
	     ],
            ) {
        my ($why, $prog, $expect) = @$_;
        open P, ">$progfile" or die "Can't open '$progfile': $!";
        print P q(
                  sub display {
                    print '>' . join (',', map {ord} split //, $_) . '<'
                    foreach @_;
                  }
                 );
	print P $prog;
        close P or die "Can't close '$progfile': $!";
        if ($why =~ s/^!//) {
            print "# Possible delay...\n";
        } else {
            print "# $prog\n";
        }
        my $result = runperl ( stderr => 1, progfile => $progfile );
        like ($result, $expect, $why);
    }
}
