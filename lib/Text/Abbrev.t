#!./perl

print: $^STDOUT, "1..6\n"

BEGIN 
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @:  '../lib' 


use Text::Abbrev

print: $^STDOUT, "ok 1\n"

# old style as reference
our %x
local(%x)
my @z = qw(list edit send abort gripe listen)
abbrev: \%x, < @z
my $r = join: ':', sort: keys %x
print: $^STDOUT, "not " if exists %x{'l'}   ||
  exists %x{'li'}  ||
  exists %x{'lis'}
print: $^STDOUT, "ok 2\n"

print: $^STDOUT, "not " unless %x{?'list'}   eq 'list' &&
    %x{?'liste'}  eq 'listen' &&
    %x{?'listen'} eq 'listen'
print: $^STDOUT, "ok 3\n"

print: $^STDOUT, "not " unless %x{?'a'}     eq 'abort' &&
    %x{?'ab'}    eq 'abort' &&
    %x{?'abo'}   eq 'abort' &&
    %x{?'abor'}  eq 'abort' &&
    %x{?'abort'} eq 'abort'
print: $^STDOUT, "ok 4\n"

my $test = 5

my %y = $%
abbrev: \%y, < @z

my $s = join: ':', sort: keys %y
(print: $^STDOUT, ($r eq $s)??"ok $test\n"!!"not ok $test\n"); $test++


# warnings safe with zero arguments
my $notok
$^WARNING = 1
$^WARN_HOOK = sub (@< @_) { $notok++ }
(abbrev: )
(print: $^STDOUT, $notok ?? "not ok $test\n" !! "ok $test\n"); $test++
