
print "1..2\n";

# should encoded the string as encoded in UTF-8

require MIME::Base64;

try {
    my $tmp = MIME::Base64::encode("\x{12c}");
    print "# enc: $tmp\n";
};
print "not " if $@;
print "ok 1\n";

require MIME::QuotedPrint;

try {
    my $tmp = MIME::QuotedPrint::encode("\x{12c}");
    print "# enc: $tmp\n";
};
print "not " if $@;
print "ok 2\n";

