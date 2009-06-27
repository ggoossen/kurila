#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#


use Storable < qw(freeze thaw dclone)
our ($debugging, $verbose)

print $^STDOUT, "1..8\n"

sub ok($testno, $ok)
    print $^STDOUT, "not " unless $ok
    print $^STDOUT, "ok $testno\n"



# Uncomment the folowing line to get a dump of the constructed data structure
# (you may want to reduce the size of the hashes too)
# $debugging = 1;

our $gotdd

our $hashsize = 100
our $maxhash2size = 100
our $maxarraysize = 100

# Use MD5 if its available to make random string keys

try { require "MD5.pm" }
our $gotmd5 = !$^EVAL_ERROR

# Use Data::Dumper if debugging and it is available to create an ASCII dump

if ($debugging)
    try { require "Data/Dumper.pm" }
    our $gotdd  = !$^EVAL_ERROR


our @fixed_strings = @("January", "February", "March", "April", "May", "June",
                       "July", "August", "September", "October", "November", "December" )

# Build some arbitrarily complex data structure starting with a top level hash
# (deeper levels contain scalars, references to hashes or references to arrays);

our (%a1, %a2)
for my $i (0 .. $hashsize -1)
    my $k = int(rand(1_000_000))
    $k = MD5->hexhash($k) if $gotmd5 and int(rand(2))
    %a1{+$k} = \%( key => "$k", "value" => $i )

    # A third of the elements are references to further hashes

    if (int(rand(1.5)))
        my $hash2 = \%()
        my $hash2size = int(rand($maxhash2size))
        while ($hash2size--)
            my $k2 = $k . $i . int(rand(100))
            $hash2->{+$k2} = @fixed_strings[rand(int(nelems @fixed_strings))]
        
        %a1{$k}->{+value} = $hash2
    elsif (int(rand(2)))
        my $arr_ref = \$@
        my $arraysize = int(rand($maxarraysize))
        while ($arraysize--)
            push($arr_ref->@, @fixed_strings[rand(int(nelems @fixed_strings))])
        
        %a1{$k}->{+value} = $arr_ref
    



print $^STDERR, < Data::Dumper::Dumper(\%a1) if ($verbose and $gotdd)


# Copy the hash, element by element in order of the keys

foreach my $k (sort keys %a1)
    %a2{+$k} = \%( key => "$k", "value" => %a1{$k}->{?value} )


# Deep clone the hash

my $a3 = dclone(\%a1)

# In canonical mode the frozen representation of each of the hashes
# should be identical

$Storable::canonical = 1

my $x1 = freeze(\%a1)
my $x2 = freeze(\%a2)
my $x3 = freeze($a3)

ok 1, (length($x1) +> $hashsize)	# sanity check
ok 2, length($x1) == length($x2)	# idem
ok 3, $x1 eq $x2
ok 4, $x1 eq $x3

# In normal mode it is exceedingly unlikely that the frozen
# representaions of all the hashes will be the same (normally the hash
# elements are frozen in the order they are stored internally,
# i.e. pseudo-randomly).

$Storable::canonical = 0

$x1 = freeze(\%a1)
$x2 = freeze(\%a2)
$x3 = freeze($a3)


# Two out of three the same may be a coincidence, all three the same
# is much, much more unlikely.  Still it could happen, so this test
# may report a false negative.

ok 5, ($x1 ne $x2) || ($x1 ne $x3)


# Ensure refs to "undef" values are properly shared
# Same test as in t/dclone.t to ensure the "canonical" code is also correct

my $hash = \%:
push $hash->%{+''}, \$hash->%{+a}
ok 6, $hash->%{''}[0] \== \$hash->%{+a}

my $cloned = dclone(dclone($hash))
ok 7, $cloned->%{''}[0] \== \$cloned->%{+a}

$cloned->%{+a} = "blah"
ok 8, $cloned->{''}[0] \== \$cloned->%{+a}
