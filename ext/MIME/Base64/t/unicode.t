BEGIN {
	unless ($] >= 5.006) {
		print "1..0\n";
		exit(0);
	}
        if ($ENV{PERL_CORE}) {
                chdir 't' if -d 't';
                @INC = '../lib';
        }
}

print "1..2\n";

# should encoded the string as encoded in UTF-8

require MIME::Base64;

eval {
    my $tmp = MIME::Base64::encode(v300);
    print "# enc: $tmp\n";
};
print "not " if $@;
print "ok 1\n";

require MIME::QuotedPrint;

eval {
    my $tmp = MIME::QuotedPrint::encode(v300);
    print "# enc: $tmp\n";
};
print "not " if $@;
print "ok 2\n";

