#!./perl
#
#  Copyright (c) 1995-2000, Raphael Manfredi
#  
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

BEGIN {
    if (env::var('PERL_CORE')){
	push $^INCLUDE_PATH, '../ext/Storable/t';
    }
    require 'st-dump.pl';
}


use Storable < qw(dclone);

print $^STDOUT, "1..10\n";

$a = 'toto';
$b = \$a;
our $c = bless \%(), 'CLASS';
$c->{+attribute} = 'attrval';
our %a = %('key', 'value', 1, 0, $a, $b, 'cvar', \$c);
our @a = @('first', undef, 3, -4, -3.14159, 456, 4.5,
	$b, \$a, $a, $c, \$c, \%a);

print $^STDOUT, "not " unless defined (our $aref = dclone(\@a));
print $^STDOUT, "ok 1\n";

our $dumped = &dump(\@a);
print $^STDOUT, "ok 2\n";

our $got = &dump($aref);
print $^STDOUT, "ok 3\n";

print $^STDOUT, "not " unless $got eq $dumped; 
print $^STDOUT, "ok 4\n";

package FOO; our @ISA = qw(Storable);

sub make {
	my $self = bless \%();
	$self->{+key} = \%main::a;
	return $self;
};

package main;

our $foo = FOO->make;
print $^STDOUT, "not " unless defined(our $r = $foo->dclone);
print $^STDOUT, "ok 5\n";

print $^STDOUT, "not " unless &dump($foo) eq &dump($r);
print $^STDOUT, "ok 6\n";

# Ensure refs to "undef" values are properly shared during cloning
my $hash;
push @{%$hash{+''}}, \%$hash{+a};
print $^STDOUT, "not " unless %$hash{''}->[0] \== \%$hash{+a};
print $^STDOUT, "ok 7\n";

my $cloned = dclone(dclone($hash));
print $^STDOUT, "not " unless %$cloned{''}->[0] \== \%$cloned{+a};
print $^STDOUT, "ok 8\n";

%$cloned{+a} = "blah";
print $^STDOUT, "not " unless %$cloned{''}->[0] \== \%$cloned{+a};
print $^STDOUT, "ok 9\n";

# [ID 20020221.007] SEGV in Storable with empty string scalar object
package TestString;
sub new($type, $string) {
    return bless(\$string, $type);
}
package main;
my $empty_string_obj = TestString->new('');
my $clone = dclone($empty_string_obj);
# If still here after the dclone the fix (#17543) worked.
print $^STDOUT, ref $clone eq ref $empty_string_obj &&
      $$clone eq $$empty_string_obj &&
      $$clone eq '' ?? "ok 10\n" !! "not ok 10\n";

