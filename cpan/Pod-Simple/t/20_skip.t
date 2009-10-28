# 20 skip under 5.8

print: $^STDOUT, "1..2\n"
print: $^STDOUT, "# Running under Perl $^PERL_VERSION\n"
print: $^STDOUT, "ok 1\n"
print: $^STDOUT, "# ^ not skipping\n"

print: $^STDOUT, "ok 2\n"

