#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

sub BEGIN {
    if (%ENV{PERL_CORE}){
	push @INC, '../ext/Storable/t';
    }
    require 'st-dump.pl';
}


use Storable qw(dclone);

print "1..12\n";

$a = 'toto';
$b = \$a;
our $c = bless \%(), 'CLASS';
$c->{attribute} = 'attrval';
our %a = %('key', 'value', 1, 0, $a, $b, 'cvar', \$c);
our @a = @('first', undef, 3, -4, -3.14159, 456, 4.5,
	$b, \$a, $a, $c, \$c, \%a);

print "not " unless defined (our $aref = dclone(\@a));
print "ok 1\n";

our $dumped = &dump(\@a);
print "ok 2\n";

our $got = &dump($aref);
print "ok 3\n";

print "not " unless $got eq $dumped; 
print "ok 4\n";

package FOO; our @ISA = @( qw(Storable) );

sub make {
	my $self = bless \%();
	$self->{key} = \%main::a;
	return $self;
};

package main;

our $foo = FOO->make;
print "not " unless defined(our $r = $foo->dclone);
print "ok 5\n";

print "not " unless &dump($foo) eq &dump($r);
print "ok 6\n";

# Ensure refs to "undef" values are properly shared during cloning
my $hash;
push @{%$hash{''}}, \%$hash{a};
print "not " unless %$hash{''}->[0] \== \%$hash{a};
print "ok 7\n";

my $cloned = dclone(dclone($hash));
print "not " unless %$cloned{''}->[0] \== \%$cloned{a};
print "ok 8\n";

%$cloned{a} = "blah";
print "not " unless %$cloned{''}->[0] \== \%$cloned{a};
print "ok 9\n";

# [ID 20020221.007] SEGV in Storable with empty string scalar object
package TestString;
sub new {
    my ($type, $string) = < @_;
    return bless(\$string, $type);
}
package main;
my $empty_string_obj = TestString->new('');
my $clone = dclone($empty_string_obj);
# If still here after the dclone the fix (#17543) worked.
print ref $clone eq ref $empty_string_obj &&
      $$clone eq $$empty_string_obj &&
      $$clone eq '' ? "ok 10\n" : "not ok 10\n";


# Do not fail if Tie::Hash and/or Tie::StdHash is not available
if (try { require Tie::Hash; scalar keys %{Symbol::stash("Tie::StdHash")} }) {
    tie my %tie, "Tie::StdHash" or die $!;
    %tie{array} = \@(1,2,3,4);
    %tie{hash} = \%(1,2,3,4);
    my $clone_array = dclone %tie{array};
    print "not " unless "{join ' ', <@$clone_array}" eq "{join ' ', <@{%tie{array}}}";
    print "ok 11\n";
    my $clone_hash = dclone %tie{hash};
    print "not " unless $clone_hash->{1} eq %tie{hash}{1};
    print "ok 12\n";
} else {
    print <<EOF;
ok 11 # skip No Tie::StdHash available
ok 12 # skip No Tie::StdHash available
EOF
}
