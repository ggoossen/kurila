print "1..2\n";

use Digest::MD5 ();

$md5 = Digest::MD5->new;

eval {
   use vars qw(*FOO);
   $md5->addfile(*FOO);
};
print "not " unless $@ =~ m/^Bad filehandle: FOO at/;
print "ok 1\n";

open(BAR, "<", "no-existing-file.$$");
eval {
    $md5->addfile(*BAR);
};
print "not " unless $@ =~ m/^No filehandle passed at/;
print "ok 2\n";
