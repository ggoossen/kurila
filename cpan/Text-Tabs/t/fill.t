#!/usr/bin/perl -w -I.


our @tests =split: m/\nEND\n/s, <<DONE
TEST1
Cyberdog Information

Cyberdog & Netscape in the news
Important Press Release regarding Cyberdog and Netscape. Check it out! 

Cyberdog Plug-in Support!
Cyberdog support for Netscape Plug-ins is now available to download! Go
to the Cyberdog Beta Download page and download it now! 

Cyberdog Book
Check out Jesse Feiler's way-cool book about Cyberdog. You can find
details out about the book as well as ordering information at Philmont
Software Mill site. 

Java!
Looking to view Java applets in Cyberdog 1.1 Beta 3? Download and install
the Mac OS Runtime for Java and try it out! 

Cyberdog 1.1 Beta 3
We hope that Cyberdog and OpenDoc 1.1 will be available within the next
two weeks. In the meantime, we have released another version of
Cyberdog, Cyberdog 1.1 Beta 3. This version fixes several bugs that were
reported to us during out public beta period. You can check out our release
notes to see what we fixed! 
END
    Cyberdog Information
    Cyberdog & Netscape in the news Important Press Release regarding
 Cyberdog and Netscape. Check it out! 
    Cyberdog Plug-in Support! Cyberdog support for Netscape Plug-ins is now
 available to download! Go to the Cyberdog Beta Download page and download
 it now! 
    Cyberdog Book Check out Jesse Feiler's way-cool book about Cyberdog.
 You can find details out about the book as well as ordering information at
 Philmont Software Mill site. 
    Java! Looking to view Java applets in Cyberdog 1.1 Beta 3? Download and
 install the Mac OS Runtime for Java and try it out! 
    Cyberdog 1.1 Beta 3 We hope that Cyberdog and OpenDoc 1.1 will be
 available within the next two weeks. In the meantime, we have released
 another version of Cyberdog, Cyberdog 1.1 Beta 3. This version fixes
 several bugs that were reported to us during out public beta period. You
 can check out our release notes to see what we fixed! 
END
DONE


$^OUTPUT_AUTOFLUSH = 1

my $numtests = (scalar: nelems @tests) / 2
print: $^STDOUT, "1..$numtests\n"

use Text::Wrap


my $rerun = (env::var: 'PERL_DL_NONLAZY') ?? 0 !! 1

my $tn = 1
while ((nelems @tests))
    my $in = shift: @tests
    my $out = shift: @tests

    $in =~ s/^TEST(\d+)?\n//

    my $back = fill: '    ', ' ', $in

    if ($back eq $out)
        print: $^STDOUT, "ok $tn\n"
    elsif ($rerun)
        my $oi = $in
        write_file: "#o", $back
        write_file: "#e", $out
        foreach ((@: $in, $back, $out))
            s/\t/^I\t/gs
            s/\n/\$\n/gs
        
        print: $^STDOUT, "------------ input ------------\n"
        print: $^STDOUT, $in
        print: $^STDOUT, "\n------------ output -----------\n"
        print: $^STDOUT, $back
        print: $^STDOUT, "\n------------ expected ---------\n"
        print: $^STDOUT, $out
        print: $^STDOUT, "\n-------------------------------\n"
        $Text::Wrap::debug = 1
        fill: '    ', ' ', $oi
        exit: 1
    else
        print: $^STDOUT, "not ok $tn\n"
    
    $tn++


sub write_file($f, @< @data)

    (open: my $fh, ">", "$f") || die: "open >$f: $^OS_ERROR"
    ((print: $fh, < @data)) || die: "write $f: $^OS_ERROR"
    (close: $fh) || die: "close $f: $^OS_ERROR"
    return 1

