#!./perl

BEGIN { require './test.pl'; }

plan( tests => 26 );

# simple error object.
{
    my $err = error::create("my message"); my $line1 = __LINE__;
    ok $err, "error object created";
    is ref $err, "error";
    is $err->{description}, "my message";
    is $err->message, "my message at ../lib/error.t line $line1.\n", "message function";
}

# a bit more complex one, with stack trace.
{
    my ($line1, $line2, $line3);
    sub new_error { return error::create("my message"); } $line1 = __LINE__;
    sub new_error2 { return new_error(); } $line2 = __LINE__;
    $err = new_error2(); $line3 = __LINE__;
    is( (scalar @{$err->{stack}}), 2);
    is((join '**', @{$err->{stack}[0]}), "main**../lib/error.t**$line2**main::new_error**");
    is((join '**', @{$err->{stack}[1]}), "main**../lib/error.t**$line3**main::new_error2**");
    is $err->message, <<MSG ;
my message at ../lib/error.t line $line1.
    main::new_error called at ../lib/error.t line $line2.
    main::new_error2 called at ../lib/error.t line $line3.
MSG
}

# creating the error object using 'die' inside an 'eval'
{
    my ($line1, $line2);
    eval { $line1 = __LINE__;
           $line2 = __LINE__; die "foobar";
       };
    is defined $@, 1, '$@ is set';
    is ref $@, "error", '$@ is an error object';
    is $@->{description}, "foobar";
    is $@->message, <<MSG;
foobar at ../lib/error.t line $line2.
    (eval) called at ../lib/error.t line $line1.
MSG
}

# creating the error object using 'die' inside an 'eval' in an 'eval'
{
    my $err;
    my ($line1, $line2);
    eval { $line2 = __LINE__;
        eval { die "my die"; }; $line1 = __LINE__;
        $err = $@;
    };
    is defined $err, 1, '$@ is set';
    is ref $err, "error", '$@ is error object';
    is $err->message, <<MSG;
my die at ../lib/error.t line $line1.
    (eval) called at ../lib/error.t line $line1.
    (eval) called at ../lib/error.t line $line2.
MSG
}

# die without arguments, reuses $@
{
    my ($line1, $line2);
    eval { $line2 = __LINE__;
        eval { die "reuse die"; }; $line1 = __LINE__;
        die;
    };
    is ref $@, "error", '$@ is an error object';
    is $@->message, <<MSG;
reuse die at ../lib/error.t line $line1.
    (eval) called at ../lib/error.t line $line1.
    (eval) called at ../lib/error.t line $line2.
MSG
}

# Internal Perl_croak routines also make error objects
{
    my $line1;
    eval { my $foo = "xx"; $$foo; }; $line1 = __LINE__;
    is defined $@, 1, '$@ is set';
    is ref $@, 'error', '$@ is an error object';
    is $@->message, <<MSG;
Can't use string ("xx") as a SCALAR ref while "strict refs" in use at ../lib/error.t line $line1.
    (eval) called at ../lib/error.t line $line1.
MSG
}

# Writing the standard message
{
    fresh_perl_is("die 'foobar'",
                  'foobar at - line 1.');
}

# Compilation error
{
    fresh_perl_is('BEGIN { die "foobar" }', <<MSG );
foobar at - line 1.
BEGIN failed--compilation aborted
MSG
}

# yyerror
{
    eval 'undef foo';
    is defined $@, 1, '$@ is set';
    is ref $@, 'error', '$@ is error object';
    is $@->message, <<MSG ;
Can't modify constant item in undef operator at (eval 9) line 2, at EOF
Bareword \"foo\" not allowed while "strict subs" in use at (eval 9) line 1, at EOF
 at ../lib/error.t line 107.
MSG
}

# Compilation error with '#line X'
{
    fresh_perl_is("use strict;\n\$x = 1;\n\$y = 1;\n", <<'MSG' );
Global symbol "$x" requires explicit package name at - line 2, near "$x "
Global symbol "$y" requires explicit package name at - line 3, near "$y "
Execution of - aborted due to compilation errors. at - line 3.
MSG
}
