#!./perl

#
# test the logical operators '&&', '||', '!', 'and', 'or', 'not'
#

print $^STDOUT, "1..7\n";

my $test = 0;
for my $i (@(undef, < 0 .. 2, "", "0 but true")) {
    my $true = 1;
    my $false = 0;
    for my $j (@(undef, < 0 .. 2, "", "0 but true")) {
	$true &&= !(
	    ((!$i || !$j) != !($i && $j))
	    or (!($i || $j) != (!$i && !$j))
	    or ( ! ! ($i || $j) != !(!$i && !$j))
	    or (!(!$i || !$j) != ! ! ($i && $j))
	);
	$false ||= (
	    ((!$i || !$j) == ! ! ($i && $j))
	    and (! !($i || $j) == (!$i && !$j))
	    and ((!$i || $j) == ($i && !$j))
	    and (($i || !$j) != (!$i && $j))
	);
    }
    if (not $true) {
	print $^STDOUT, "not ";
    } elsif ($false) {
	print $^STDOUT, "not ";
    }
    print $^STDOUT, "ok ", ++$test, "\n";
}

# $test == 6
my $i = 0;
(($i ||= 1) &&= 3) += 4;
print $^STDOUT, "not " unless $i == 7;
print $^STDOUT, "ok ", ++$test, "\n";
