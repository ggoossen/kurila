#!./perl

BEGIN {
    chdir 't' if -d 't';
    @INC = @( '../lib' );
}

print "1..4\n";

use strict;

my $DICT = <<EOT;
Aarhus
Aaron
Ababa
aback
abaft
abandon
abandoned
abandoning
abandonment
abandons
abase
abased
abasement
abasements
abases
abash
abashed
abashes
abashing
abasing
abate
abated
abatement
abatements
abater
abates
abating
Abba
EOT

use Search::Dict;

open(my $dict_fh, "+>", "dict-$$") or die "Can't create dict-$$: $!";
binmode $dict_fh;			# To make length expected one.
print $dict_fh $DICT;

my $pos = look $dict_fh, "Ababa";
chomp(my $word = ~< $dict_fh);
print "not " if $pos +< 0 || $word ne "Ababa";
print "ok 1\n";

$pos = look $dict_fh, "foo";
chomp($word = ~< $dict_fh);

print "not " if $pos != length($DICT);  # will search to end of file
print "ok 2\n";

my $pos = look $dict_fh, "abash";
chomp($word = ~< $dict_fh);
print "not " if $pos +< 0 || $word ne "abash";
print "ok 3\n";

$pos = look $dict_fh, "aarhus", 1, 1;
chomp($word = ~< $dict_fh);

print "not " if $pos +< 0 || $word ne "Aarhus";
print "ok 4\n";

close $dict_fh or die "cannot close";
unlink "dict-$$";
