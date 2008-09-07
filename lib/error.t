#!./perl

BEGIN { require './test.pl'; }

plan( tests => 26 );

# simple error object.
{
    my $err = error::create("my message", @("filetest.t", 33, 11));
    ok $err, "error object created";
    is ref $err, "error";
    is $err->{description}, "my message";
    is $err->message, "my message at filetest.t line 33 character 11.\n", "message function";
}

# a bit more complex one, with stack trace.
{
    my ($line1, $line2, $line3);
    sub new_error { return error::create("my message"); } $line1 = __LINE__;
    sub new_error2 { return new_error(); } $line2 = __LINE__;
    my $err = new_error2(); $line3 = __LINE__;
    is( (nelems $err->{stack}), 2);
    is((join '**', $err->{stack}[0]), "../lib/error.t**$line2**29**main::new_error**");
    is((join '**', $err->{stack}[1]), "../lib/error.t**$line3**15**main::new_error2**");
    is $err->message, <<MSG ;
my message
    main::new_error called at ../lib/error.t line $line2 character 29.
    main::new_error2 called at ../lib/error.t line $line3 character 15.
MSG
}

# creating the error object using 'die' inside an 'eval'
{
    my ($line1, $line2);
    try { $line1 = __LINE__;
           $line2 = __LINE__; die "foobar";
       };
    is defined $@, 1, '$@ is set';
    is ref $@, "error", '$@ is an error object';
    is $@->{description}, "foobar";
    is $@->message, <<MSG;
foobar at ../lib/error.t line $line2 character 31.
    (eval) called at ../lib/error.t line $line1 character 5.
MSG
}

# creating the error object using 'die' inside an 'eval' in an 'eval'
{
    my $err;
    my ($line1, $line2);
    try { $line2 = __LINE__;
        try { die "my die"; }; $line1 = __LINE__;
        $err = $@;
    };
    is defined $err, 1, '$@ is set';
    is ref $err, "error", '$@ is error object';
    is $err->message, <<MSG;
my die at ../lib/error.t line $line1 character 15.
    (eval) called at ../lib/error.t line $line1 character 9.
    (eval) called at ../lib/error.t line $line2 character 5.
MSG
}

# die without arguments, reuses $@
{
    my ($line1, $line2);
    try { $line2 = __LINE__;
        try { die "reuse die"; }; $line1 = __LINE__;
        die;
    };
    is ref $@, "error", '$@ is an error object';
    is $@->message, <<MSG;
reuse die at ../lib/error.t line $line1 character 15.
    (eval) called at ../lib/error.t line $line1 character 9.
    (eval) called at ../lib/error.t line $line2 character 5.
reraised at ../lib/error.t line {$line1+1} character 9.
MSG
}

# Internal Perl_croak routines also make error objects
{
    my $line1;
    try { my $foo = "xx"; $$foo; }; $line1 = __LINE__;
    is defined $@, 1, '$@ is set';
    is ref $@, 'error', '$@ is an error object';
    is $@->message, <<MSG;
Can't use PLAINVALUE as a SCALAR REF at ../lib/error.t line $line1 character 26.
    (eval) called at ../lib/error.t line $line1 character 5.
MSG
}

# Writing the standard message
{
    fresh_perl_is("die 'foobar'",
                  'foobar at - line 1 character 1.');
}

# Compilation error
{
    fresh_perl_is('BEGIN { die "foobar" }', <<MSG );
foobar at - line 1 character 9.
BEGIN failed--compilation aborted
MSG
}

# yyerror
{
    eval 'undef foo'; my $line = __LINE__;
    is defined $@, 1, '$@ is set';
    is ref $@, 'error', '$@ is error object';
    is $@->message, <<MSG ;
Can't modify constant item in undef operator at (eval 9) line 1 character 7.
    (eval) called at ../lib/error.t line $line character 5.
MSG
}

# Compilation error with '#line X'
{
    fresh_perl_is("use strict;\n\$x = 1;\n\$y = 1;\n", <<'MSG' );
Global symbol "$x" requires explicit package name at - line 2, near "$x "
Global symbol "$y" requires explicit package name at - line 3, near "$y "
Execution of - aborted due to compilation errors.
MSG
}
