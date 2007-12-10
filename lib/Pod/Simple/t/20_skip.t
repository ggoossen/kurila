# 20 skip under 5.8
BEGIN {
    if($ENV{PERL_CORE}) {
        chdir 't';
        @INC = '../lib';
    }
}

print "1..2\n";
  print "# Running under Perl $^V\n";
  print "ok 1\n";
  print "# ^ not skipping\n";

print "ok 2\n";

