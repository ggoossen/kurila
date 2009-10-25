#!./perl

BEGIN { require './test.pl'; }

plan:  tests => 34 

# simple error object.
do
    my $err = error::create: "my message", (@: "filetest.t", 33, 11)
    ok: $err, "error object created"
    is: ref $err, "error"
    is: $err->{?description}, "my message"
    is: ($err->description: ), "my message", "message function"
    is: ($err->stacktrace: ), " at filetest.t line 33 character 11.\n"
        "stacktrace function"
    is: ($err->message: ), "my message at filetest.t line 33 character 11.\n"
        "message function"


# a bit more complex one, with stack trace.
do
    my ($line1, $line2, $line3);
    sub new_error { return (error::create: "my message"); } $line1 = __LINE__;
    sub new_error2 { return (new_error: ); } $line2 = __LINE__
    my $err = (new_error2: ); $line3 = __LINE__
    is:  (nelems $err->{stack}), 2
    is: ((join: '**', $err->{stack}[0])), "../lib/error.t**$line2**30**main::new_error**"
    is: ((join: '**', $err->{stack}[1])), "../lib/error.t**$line3**16**main::new_error2**"
    is: ($err->description: ), "my message"
    is: ($err->stacktrace: ), <<MSG

    main::new_error called at ../lib/error.t line $line2 character 30.
    main::new_error2 called at ../lib/error.t line $line3 character 16.
MSG


# creating the error object using 'die' inside an 'eval'
do
    my ($line1, $line2)
    try { $line1 = __LINE__;
        $line2 = __LINE__; die: "foobar";
    }
    is: defined $^EVAL_ERROR, 1, '$@ is set'
    is: ref $^EVAL_ERROR, "error", '$@ is an error object'
    is: $^EVAL_ERROR->{?description}, "foobar"
    is: ($^EVAL_ERROR->description: ), "foobar"
    is: ($^EVAL_ERROR->stacktrace: ), <<MSG
 at ../lib/error.t line $line2 character 28.
    (try) called at ../lib/error.t line $line1 character 5.
MSG


# creating the error object using 'die' inside an 'eval' in an 'eval'
do
    my $err
    my ($line1, $line2)
    try { $line2 = __LINE__;
        try { (die: "my die"); }; $line1 = __LINE__;
        $err = $^EVAL_ERROR;
    }
    is: defined $err, 1, '$@ is set'
    is: ref $err, "error", '$@ is error object'
    is: ($err->description: ), "my die"
    is: ($err->stacktrace: ), <<MSG
 at ../lib/error.t line $line1 character 16.
    (try) called at ../lib/error.t line $line1 character 9.
    (try) called at ../lib/error.t line $line2 character 5.
MSG


# die without arguments, reuses $@
do
    my ($line1, $line2)
    try { $line2 = __LINE__;
        try { (die: "reuse die"); }; $line1 = __LINE__;
        (die: );
    }
    is: ref $^EVAL_ERROR, "error", '$@ is an error object'
    is: ($^EVAL_ERROR->description: ), "reuse die"
    is: ($^EVAL_ERROR->stacktrace: ), <<MSG
 at ../lib/error.t line $line1 character 16.
    (try) called at ../lib/error.t line $line1 character 9.
    (try) called at ../lib/error.t line $line2 character 5.
reraised at ../lib/error.t line $($line1+1) character 10.
MSG


# Internal Perl_croak routines also make error objects
do
    my $line1
    try { my $foo = "xx"; $foo->$; }; $line1 = __LINE__
    is: defined $^EVAL_ERROR, 1, '$@ is set'
    is: ref $^EVAL_ERROR, 'error', '$@ is an error object'
    is: ($^EVAL_ERROR->description: ), "Expected a SCALAR REF but got a PLAINVALUE"
    is: ($^EVAL_ERROR->stacktrace: ), <<MSG
 at ../lib/error.t line $line1 character 31.
    (try) called at ../lib/error.t line $line1 character 5.
MSG


# Writing the standard message
do
    fresh_perl_is: "die: 'foobar'"
                   'foobar at - line 1 character 1.'


# Compilation error
do
    fresh_perl_is: 'BEGIN { die: "foobar" }', <<MSG 
foobar at - line 1 character 9.
    BEGIN called at - line 1 character 1.
MSG


# yyerror
do
    eval 'undef "foo"'; my $line = __LINE__
    is: defined $^EVAL_ERROR, 1, '$@ is set'
    is: ref $^EVAL_ERROR, 'error', '$@ is error object'
    is: ($^EVAL_ERROR->description: ), "Can't modify constant item in undef operator"
    is: ($^EVAL_ERROR->stacktrace: ), <<MSG 
 at (eval 9) line 1 character 12.
    (eval) called at ../lib/error.t line $line character 5.
MSG


# Compilation error with '#line X'
do
    fresh_perl_is: "\$x = 1;\n\$y = 1;\n", <<'MSG' 
Global symbol "$x" requires explicit package name at - line 1, near "$x"
Global symbol "$y" requires explicit package name at - line 2, near "$y"
Execution of - aborted due to compilation errors.
MSG

