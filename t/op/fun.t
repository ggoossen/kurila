#!./perl

BEGIN { require './test.pl'; }

# Check ck_fun stuff.

plan (3);

# OA_AVREF
{
    # array without '@'.
    no strict 'vars';
    our @foox = ( 'foo', 'bar', 'burbl');
    eval q| push(foox, 'blah') |;
    like($@->message, qr/Type of arg 1 to push must be array/);
    is(0+@foox, 3);
}

# OA_HVREF
{
    # hash without '%'.
    no strict 'vars';
    our %foox = ( foo => 'bar' );
    eval q| keys foox |;
    like($@ && $@->message, qr/Type of arg 1 to keys must be hash/);
}
