#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    our %Config;
    require Config; Config->import;
    if (!$Config{d_setlocale} || $Config{ccflags} =~ m/\bD?NO_LOCALE\b/) {
	print "1..0\n";
	exit;
    }
}

print "1..7\n";

use I18N::Collate;

print "ok 1\n";

$a = I18N::Collate->new("foo");

print "ok 2\n";

{
    use warnings;
    local ${^WARN_HOOK} = sub { $@ = $_[0] };
    $b = I18N::Collate->new("foo");
    print "not " unless $@->{description} =~ m/\bHAS BEEN DEPRECATED\b/;
    print "ok 3\n";
    $@ = '';
}

print "not " unless $a eq $b;
print "ok 4\n";

$b = I18N::Collate->new("bar");
print "not " if $@ && $@->{description} =~ m/\bHAS BEEN DEPRECATED\b/;
print "ok 5\n";

print "not " if $a eq $b;
print "ok 6\n";

print "not " if ($a cmp $b) == ($b cmp $a);
print "ok 7\n";

