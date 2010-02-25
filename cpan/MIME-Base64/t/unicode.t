
print: $^STDOUT, "1..2\n"

# should encoded the string as encoded in UTF-8

require MIME::Base64

try {
    my $tmp = (MIME::Base64::encode: "\x{12c}");
    print: $^STDOUT, "# enc: $tmp\n";
}
print: $^STDOUT, "not " if $^EVAL_ERROR
print: $^STDOUT, "ok 1\n"

require MIME::QuotedPrint

try {
    my $tmp = (MIME::QuotedPrint::encode: "\x{12c}");
    print: $^STDOUT, "# enc: $tmp\n";
}
print: $^STDOUT, "not " if $^EVAL_ERROR
print: $^STDOUT, "ok 2\n"

