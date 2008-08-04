#!./perl

BEGIN { require './test.pl'; }

# Check ck_fun stuff.

plan (2);

# OA_AVREF
{
    # array without '@'.
    no strict 'vars';
    our @foox = @( 'foo', 'bar', 'burbl');
    eval q| push(foox, 'blah') |;
    like($@->message, qr/Type of arg 1 to push must be array/);
    is(0+nelems @foox, 3);
}
