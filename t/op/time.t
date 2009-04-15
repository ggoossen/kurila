#!./perl

our $does_gmtime = gmtime(time);

BEGIN {
    require './test.pl';
}

plan tests => 8;

our @($beguser,$begsys, ...) = @: times;

our $beg = time;

our $now;
while (($now = time) == $beg) { sleep 1 }

ok($now +> $beg && $now - $beg +< 10,             'very basic time test');

our $i = 0;
while ($i +< 1_000_000) {
    for my $j (1..100) {}; # burn some user cycles
    my @($nowuser, $nowsys, ...) = @: times;
    $i = 2_000_000 if $nowuser +> $beguser && ( $nowsys +>= $begsys ||
                                            (!$nowsys && !$begsys));
    last if time - $beg +> 20;

    $i++;
}

ok($i +>= 2_000_000, 'very basic times test');

our @($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @: localtime($beg);
our @($xsec,$foo, ...) = @: localtime($now);
our $localyday = $yday;

ok($sec != $xsec && $mday && $year,             'localtime() list context');

ok(localtime() =~ m/^(Sun|Mon|Tue|Wed|Thu|Fri|Sat)[ ]
                    (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[ ]
                    ([ \d]\d)\ (\d\d):(\d\d):(\d\d)\ (\d{4})$
                  /x,
   'localtime(), scalar context'
  );

SKIP: do {
    # This conditional of "No tzset()" is stolen from ext/POSIX/t/time.t
    skip "No tzset()", 1
        if $^OS_NAME eq "MacOS" || $^OS_NAME eq "VMS" || $^OS_NAME eq "cygwin" ||
           $^OS_NAME eq "djgpp" || $^OS_NAME eq "MSWin32" || $^OS_NAME eq "dos" ||
           $^OS_NAME eq "interix";

# check that localtime respects changes to $ENV{TZ}
env::var('TZ' ) = "GMT-5";
@($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @: localtime($beg);
env::var('TZ' ) = "GMT+5";
my @($sec,$min,$hour2,$mday,$mon,$year,$wday,$yday,$isdst) = @: localtime($beg);
ok($hour != $hour2,                             'changes to $ENV{TZ} respected');
};

SKIP: do {
    skip "No gmtime()", 3 unless $does_gmtime;

@($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = @: gmtime($beg);
@($xsec,$foo, ...) = @: localtime($now);

ok($sec != $xsec && $mday && $year,             'gmtime() list context');

my $day_diff = $localyday - $yday;
ok( grep({ $day_diff == $_ }, @( (0, 1, -1, 364, 365, -364, -365))),
                     'gmtime() and localtime() agree what day of year');


# This could be stricter.
ok(gmtime() =~ m/^(Sun|Mon|Tue|Wed|Thu|Fri|Sat)[ ]
                 (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[ ]
                 ([ \d]\d)\ (\d\d):(\d\d):(\d\d)\ (\d{4})$
               /x,
   'gmtime(), scalar context'
  );
};
