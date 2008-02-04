print "1..2\n";

use Digest::MD5 ();

$md5 = Digest::MD5->new;

eval {
   use vars qw(*FOO);
   $md5->addfile(*FOO);
};
print "not " unless $@->{description} =~ m/^Bad filehandle: FOO/;
print "ok 1\n";

open(BAR, "<", "no-existing-file.$$");
eval {
    $md5->addfile(*BAR);
};
print "not " unless $@->{description} =~ m/^No filehandle passed/;
print "ok 2\n";
