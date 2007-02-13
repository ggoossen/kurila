#!./perl

BEGIN {
require "utf8.pm";
require "utf8_heavy.pl";
}

# my $c = 1;

# use re 'Debug', 'ALL';

# use utf8;
# my $subject = "\nx aa";

#                 $match = ($subject =~ m'^\S\s+aa$'m) while $c--;
#                 $got = "-";
# warn $match;
# warn $got;

# __END__
$skip_amp = 1;
for $file ('./op/regexp.t', './t/op/regexp.t', ':op:regexp.t') {
  if (-r $file) {
    do $file or die $@;
    exit;
  }
}
die "Cannot find ./op/regexp.t or ./t/op/regexp.t\n";
