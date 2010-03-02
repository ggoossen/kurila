#!./perl -w

BEGIN 
    require './test.pl'


plan: tests => 56

my @comma = @: "key", "value"

# The peephole optimiser already knows that it should convert the string in
# $foo{string} into a shared hash key scalar. It might be worth making the
# tokeniser build the LHS of => as a shared hash key scalar too.
# And so there's the possiblility of it going wrong
# And going right on 8 bit but wrong on utf8 keys.
# And really we should also try utf8 literals in {} and => in utf8.t

# Some of these tests are (effectively) duplicated in each.t
my %comma = %:  < @comma 
ok: (nelems: keys %comma) == 1, 'keys on comma hash'
ok: (nelems: values %comma) == 1, 'values on comma hash'
# defeat any tokeniser or optimiser cunning
my $key = 'ey'
is: %comma{?"k" . $key}, "value", 'is key present? (unoptimised)'
# now with cunning:
is: %comma{?key}, "value", 'is key present? (maybe optimised)'
#tokeniser may treat => differently.
my @temp = @: key=>undef
is: %comma{?@temp[0]}, "value", 'is key present? (using LHS of =>)'

@temp = @:  < %comma 
ok: (eq_array: \@comma, \@temp), 'list from comma hash'

@temp = @:  each %comma 
ok: (eq_array: \@comma, \@temp), 'first each from comma hash'
@temp = @:  each %comma 
ok: (eq_array: \$@, \@temp), 'last each from comma hash'

my %temp = %:  < %comma 

ok: (nelems: keys %temp) == 1, 'keys on copy of comma hash'
ok: (nelems: values %temp) == 1, 'values on copy of comma hash'
is: %temp{?'k' . $key}, "value", 'is key present? (unoptimised)'
# now with cunning:
is: %temp{?key}, "value", 'is key present? (maybe optimised)'
@temp = @: key=>undef
is: %comma{?@temp[0]}, "value", 'is key present? (using LHS of =>)'

@temp = @:  < %temp 
ok: (eq_array: \@temp, \@temp), 'list from copy of comma hash'

@temp = @:  each %temp 
ok: (eq_array: \@temp, \@temp), 'first each from copy of comma hash'
@temp = @:  each %temp 
ok: (eq_array: \$@, \@temp), 'last each from copy of comma hash'

my @arrow = @: Key =>"Value"

my %arrow = %:  < @arrow 
ok: (nelems: keys %arrow) == 1, 'keys on arrow hash'
ok: (nelems: values %arrow) == 1, 'values on arrow hash'
# defeat any tokeniser or optimiser cunning
$key = 'ey'
is: %arrow{?"K" . $key}, "Value", 'is key present? (unoptimised)'
# now with cunning:
is: %arrow{?Key}, "Value", 'is key present? (maybe optimised)'
#tokeniser may treat => differently.
@temp = @: 'Key', undef
is: %arrow{?@temp[0]}, "Value", 'is key present? (using LHS of =>)'

@temp = @:  < %arrow 
ok: (eq_array: \@arrow, \@temp), 'list from arrow hash'

@temp = @:  each %arrow 
ok: (eq_array: \@arrow, \@temp), 'first each from arrow hash'
@temp = @:  each %arrow 
ok: (eq_array: \$@, \@temp), 'last each from arrow hash'

%temp = %:  < %arrow 

ok: (nelems: keys %temp) == 1, 'keys on copy of arrow hash'
ok: (nelems: values %temp) == 1, 'values on copy of arrow hash'
is: %temp{?'K' . $key}, "Value", 'is key present? (unoptimised)'
# now with cunning:
is: %temp{?Key}, "Value", 'is key present? (maybe optimised)'
@temp = @: 'Key', undef
is: %arrow{?@temp[0]}, "Value", 'is key present? (using LHS of =>)'

@temp = @:< %temp
ok: (eq_array: \@temp, \@temp), 'list from copy of arrow hash'

@temp = @:  each %temp 
ok: (eq_array: \@temp, \@temp), 'first each from copy of arrow hash'
@temp = @:  each %temp 
ok: (eq_array: \$@, \@temp), 'last each from copy of arrow hash'

my %direct = %: 'Camel', 2, 'Dromedary', 1
my %slow
%slow{+Dromedary} = 1
%slow{+Camel} = 2

ok: (eq_hash: \%slow, \%direct), "direct list assignment to hash"
%direct = %: Camel => 2, 'Dromedary' => 1
ok: (eq_hash: \%slow, \%direct), "direct list assignment to hash using =>"

%slow{+Llama} = 0 # A llama is not a camel :-)
ok: !(eq_hash: \%direct, \%slow), "different hashes should not be equal!"

my (%names, %names_copy)
%names = %: '$' => 'Scalar', '@' => 'Array' # Grr '
            '%', 'Hash', '&', 'Code'
%names_copy = %:  < %names 
ok: (eq_hash: \%names, \%names_copy), "check we can copy our hash"

sub in
    my %args = %:  < @_ 
    return eq_hash: \%names, \%args


ok: (in: < %names), "pass hash into a method"

sub in_method
    my $self = shift
    my %args = %:  < @_ 
    return eq_hash: \%names, \%args


ok: (main->in_method : < %names), "pass hash into a method"

sub out
    return %names

%names_copy = %:  < (out: ) 

ok: (eq_hash: \%names, \%names_copy), "pass hash from a subroutine"

sub out_method
    my $self = shift
    return %names

%names_copy = %:  < main->out_method  

ok: (eq_hash: \%names, \%names_copy), "pass hash from a method"

sub in_out
    my %args = %:  < @_ 
    return %args

%names_copy = %:  < in_out: < %names 

ok: (eq_hash: \%names, \%names_copy), "pass hash to and from a subroutine"

sub in_out_method
    my $self = shift
    my %args = %:  < @_ 
    return %args

%names_copy = %:  < main->in_out_method : < %names 

ok: (eq_hash: \%names, \%names_copy), "pass hash to and from a method"

my %names_copy2 = %:  < %names 
ok: (eq_hash: \%names, \%names_copy2), "check copy worked"

# This should get ignored.
%names_copy = %: '%', 'Associative Array', < %names

ok: (eq_hash: \%names, \%names_copy), "duplicates at the start of a list"

# This should not
%names_copy = %: '*', 'Typeglob', < %names

%names_copy2{+'*'} = 'Typeglob'
ok: (eq_hash: \%names_copy, \%names_copy2), "duplicates at the end of a list"

%names_copy = %: '%', 'Associative Array', '*', 'Endangered species', < %names
                 '*', 'Typeglob'

ok: (eq_hash: \%names_copy, \%names_copy2), "duplicates at both ends"

# test stringification of keys
do
    no warnings 'once'
    my @refs =    @:  \ do { my $x }, \$@,   \$%,  \ sub {}, \ *x
    our %h
    for my $ref ( @refs)
        dies_like:  sub () { %h{?$ref} }, qr/reference as string/ 

    for (@refs)
        bless: $_
    %h = $%
    for my $ref ( @refs)
        dies_like:  sub () { %h{?$ref} }, qr/reference as string/ 
