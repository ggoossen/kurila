
use Test::More 'no_plan'

### use && import ###
use Params::Check < qw|check last_error allow|

### verbose is good for debugging ###
$Params::Check::VERBOSE = $Params::Check::VERBOSE = @ARGV[?0] ?? 1 !! 0

### basic things first, allow function ###

use constant FALSE  => sub (@< @_) { 0 }
use constant TRUE   => sub (@< @_) { 1 }

### allow tests ###
do {   ok:  (allow:  42, qr/^\d+$/ ), "Allow based on regex" ;
    ok:  (allow:  $^PROGRAM_NAME, $^PROGRAM_NAME),         "   Allow based on string" ;
    ok:  (allow:  42, \(@: 0,42) ),    "   Allow based on list" ;
    ok:  (allow:  42, \(@: 50,sub (@< @_){1})),"   Allow based on list containing sub";
    ok:  (allow:  42, (TRUE: )),      "   Allow based on constant sub" ;
    ok: !(allow:  $^PROGRAM_NAME, qr/^\d+$/ ), "Disallowing based on regex" ;
    ok: !(allow:  42, $^PROGRAM_NAME ),        "   Disallowing based on string" ;
    ok: !(allow:  42, \(@: 0,$^PROGRAM_NAME) ),    "   Disallowing based on list" ;
    ok: !(allow:  42, \(@: 50,sub (@< @_){0})),"   Disallowing based on list containing sub";
    ok: !(allow:  42, (FALSE: )),     "   Disallowing based on constant sub" ;

    ### check that allow short circuits where required
    do {   my $sub_called;
        allow:  1, \(@:  1, sub (@< @_) { $sub_called++ } ) ;
        ok:  !$sub_called,       "Allow short-circuits properly" ;
    };

    ### check if the subs for allow get what you expect ###
    for my $thing ((@: 1,'foo',\(@: 1)))
        allow:  $thing
               sub (@< @_) { (is_deeply: shift,$thing,  "Allow coderef gets proper args") }
               
    
}
### default tests ###
do
    my $tmpl =  \%:
        foo => %:  default => 1 

    ### empty args first ###
    do {   my $args = (check:  $tmpl, \$% );

        ok:  $args,              "check() call with empty args" ;
        is:  $args->{?'foo'}, 1,  "   got default value" ;
    }

    ### now provide an alternate value ###
    do {   my $try  = \(%:  foo => 2 );
        my $args = (check:  $tmpl, $try );

        ok:  $args,              "check() call with defined args" ;
        is_deeply:  $args, $try, "   found provided value in rv" ;
    }

    ### now provide a different case ###
    do {   my $try  = \(%:  FOO => 2 );
        my $args = (check:  $tmpl, $try );
        ok:  $args,              "check() call with alternate case" ;
        is:  $args->{?foo}, 2,    "   found provided value in rv" ;
    }

    ### now see if we can strip leading dashes ###
    do {   local $Params::Check::STRIP_LEADING_DASHES = 1;
        my $try  = \(%:  "-foo" => 2 );
        my $get  = \(%:  foo  => 2 );

        my $args = (check:  $tmpl, $try );
        ok:  $args,              "check() call with leading dashes" ;
        is_deeply:  $args, $get, "   found provided value in rv" ;
    }


### preserve case tests ###
do {   my $tmpl = \(%:  Foo => (%:  default => 1 ) );

    for ((@: 1,0))
        local $Params::Check::PRESERVE_CASE = $_

        my $expect = $_ ?? \(%:  Foo => 42 ) !! \%:  Foo => 1 

        my $rv = check:  $tmpl, \(%:  Foo => 42 ) 
        ok:  $rv,                "check() call using PRESERVE_CASE: $_" 
        is_deeply: $rv, $expect, "   found provided value in rv" 
    
}


### unknown tests ###
do
    ### disallow unknowns ###
    do
        my $rv = check:  \$%, \(%:  foo => 42 ) 

        is_deeply:  $rv, \$%,     "check() call with unknown arguments" 
        like:  (last_error: ), qr/^Key 'foo' is not a valid key/
               "   warning recorded ok" 
    

    ### allow unknown ###
    do
        local   $Params::Check::ALLOW_UNKNOWN = 1
        my $rv = check:  \$%, \(%:  foo => 42 ) 

        is_deeply:  $rv, \(%:  foo => 42 )
                    "check call() with unknown args allowed" 
    


### store tests ###
do {   my $foo;
    my $tmpl = \(%:
        foo => %:  store => \$foo 
        );

    ### with/without store duplicates ###
    for((@:  1, 0) )
        local   $Params::Check::NO_DUPLICATES = $_

        my $expect = $_ ?? undef !! 42

        my $rv = check:  $tmpl, \(%:  foo => 42 ) 
        ok:  $rv,                    "check() call with store key, no_dup: $_" 
        is:  $foo, 42,               "   found provided value in variable" 
        is:  $rv->{?foo}, $expect,    "   found provided value in variable" 
    
}

### no_override tests ###
do {   my $tmpl = \(%:
        foo => (%:  no_override => 1, default => 42 )
        );

    my $rv = (check:  $tmpl, \(%:  foo => 13 ) );
    ok:  $rv,                    "check() call with no_override key" ;
    is:  $rv->{?'foo'}, 42,       "   found default value in rv" ;

    like:  (last_error: ), qr/^You are not allowed to override key/
           "   warning recorded ok" ;
}

### strict_type tests ###
do {   my @list = (@:
        \(@:  (%:  strict_type => 1, default => \$@ ),  0 )
        \(@:  (%:  default => \$@ ),                    1 )
        );

    ### check for strict_type global, and in the template key ###
    for my $aref ( @list)

        my $tmpl = \%:  foo => $aref->[0] 
        local   $Params::Check::STRICT_TYPE = $aref->[1]

        ### proper value ###
        do {   my $rv = (check:  $tmpl, \(%:  foo => \$@ ) );
            ok:  $rv,                "check() call with strict_type enabled" ;
            is:  ref $rv->{?foo}, 'ARRAY'
                 "   found provided value in rv" ;
        }

        ### improper value ###
        do {   my $rv = (check:  $tmpl, \(%:  foo => \$% ) );
            ok:  !$rv,               "check() call with strict_type violated" ;
            like:  (last_error: ), qr/^Key 'foo' needs to be of type 'ARRAY'/
                   "   warning recorded ok" ;
        }
    
}

### required tests ###
do {   my $tmpl = \(%:
        foo => %:  required => 1 
        );

    ### required value provided ###
    do {   my $rv = (check:  $tmpl, \(%:  foo => 42 ) );
        ok:  $rv,                    "check() call with required key" ;
        is:  $rv->{?foo}, 42,         "   found provided value in rv" ;
    };

    ### required value omitted ###
    do {   my $rv = (check:  $tmpl, \$% );
        ok:  !$rv,                   "check() call with required key omitted" ;
        like:  (last_error: ), qr/^Required option 'foo' is not provided/
               "   warning recorded ok" ;
    };
}

### defined tests ###
do {   my @list = (@:
        \(@:  (%:  defined => 1, default => 1 ),  0 )
        \(@:  (%:  default => 1 ),                1 )
        );

    ### check for strict_type global, and in the template key ###
    for my $aref ( @list)

        my $tmpl = \%:  foo => $aref->[0] 
        local   $Params::Check::ONLY_ALLOW_DEFINED = $aref->[1]

        ### value provided defined ###
        do {   my $rv = (check:  $tmpl, \(%:  foo => 42 ) );
            ok:  $rv,                "check() call with defined key" ;
            is:  $rv->{?foo}, 42,     "   found provided value in rv" ;
        }

        ### value provided undefined ###
        do {   my $rv = (check:  $tmpl, \(%:  foo => undef ) );
            ok:  !$rv,               "check() call with defined key undefined" ;
            like:  (last_error: ), qr/^Key 'foo' must be defined when passed/
                   "   warning recorded ok" ;
        }
    
}

### check + allow tests ###
do   ### check if the subs for allow get what you expect ###
    for my $thing ((@: 1,'foo',\(@: 1)))
        my $tmpl = \%:
            foo => %:  allow =>
                           sub ($v) { (is_deeply: $v,$thing
                                                  "   Allow coderef gets proper args") }

        my $rv = check:  $tmpl, \(%:  foo => $thing ) 
        ok:  $rv,                    "check() call using allow key" 
    


### invalid key tests
do {   my $tmpl = \(%:  foo => (%:  allow => sub (@< @_) { 0 } ) );

    for my $val ((@:  1, 'foo', \$@, (bless: \$%,__PACKAGE__)) )
        my $rv      = check:  $tmpl, \(%:  foo => $val ) 
        my $text    = "Key 'foo' ($((dump::view: $val))) is of invalid type"
        my $re      = quotemeta $text

        ok: !$rv,                    "check() fails with unalllowed value" 
        like: (last_error: ), qr/$re/, "   $text" 
    
}

### warnings fatal test
do {   my $tmpl = \(%:  foo => (%:  allow => sub (@< @_) { 0 } ) );

    local $Params::Check::WARNINGS_FATAL = 1;

    try { (check:  $tmpl, \(%:  foo => 1 ) ) };

    ok:  $^EVAL_ERROR,             "Call dies with fatal toggled" ;
    like:  $^EVAL_ERROR->{?description},           qr/invalid type/
           "   error stored ok" ;
}

### store => \$foo tests
do   ### quell warnings
    local $^WARN_HOOK = sub {}

    my $tmpl = \%:  foo => (%:  store => '' ) 
    check:  $tmpl, \$% 

    my $re = quotemeta q|Store variable for 'foo' is not a reference!|
    like: (last_error: ), qr/$re/, "Caught non-reference 'store' variable" 


### edge case tests ###
do   ### if key is not provided, and value is '', will P::C treat
    ### that correctly?
    my $tmpl = \%:  foo => (%:  default => '' ) 
    my $rv   = check:  $tmpl, \$% 

    ok:  $rv,                    "check() call with default = ''" 
    ok:  exists $rv->{foo},      "   rv exists" 
    ok:  defined $rv->{?foo},     "   rv defined" 
    ok:  !$rv->{?foo},            "   rv false" 
    is:  $rv->{?foo}, '',         "   rv = '' " 


### big template test ###
do
    my $lastname

    ### the template to check against ###
    my $tmpl = \ %:
        firstname   =>  %:  required   => 1, defined => 1
        lastname    =>  %:  required   => 1, store => \$lastname
        gender      =>  %:  required   => 1
                            allow      => \(@: qr/M/i, qr/F/i)
        married     =>  %:  allow      => \(@: 0,1)
        age         =>  %:  default    => 21
                            allow      => qr/^\d+$/
        id_list     =>  %:  default        => \$@
                            strict_type    => 1
        phone       =>  %:  allow          => sub (@< @_) { 1 if shift }
        bureau      =>  %:  default        => 'NSA'
                            no_override    => 1

    ### the args to send ###
    my $try = \ %:
        firstname   => 'joe'
        lastname    => 'jackson'
        gender      => 'M'
        married     => 1
        age         => 21
        id_list     => \(1..3)
        phone       => '555-8844'

    ### the rv we expect ###
    my $get = \%:  < $try->%, bureau => 'NSA' 

    my $rv = check:  $tmpl, $try 

    ok:  $rv,                "elaborate check() call" 
    is_deeply:  $rv, $get,   "   found provided values in rv" 
    is:  $rv->{?lastname}, $lastname
         "   found provided values in rv" 


### $Params::Check::CALLER_DEPTH test
do
    sub wrapper { (check:  < @_ ) };
    sub inner   { (wrapper:  < @_ ) };
    sub outer   { (inner:  < @_ ) };
    outer:  \(%:  dummy => (%:  required => 1 )), \$% 

    like:  (last_error: ), qr/for .*::wrapper by .*::inner$/
           "wrong caller without CALLER_DEPTH" 

    local $Params::Check::CALLER_DEPTH = 1
    outer:  \(%:  dummy => (%:  required => 1 )), \$% 

    like:  (last_error: ), qr/for .*::inner by .*::outer$/
           "right caller with CALLER_DEPTH" 


### test: #23824: Bug concering the loss of the last_error
### message when checking recursively.
do {   ok:  1,                      "Test last_error() on recursive check() call" ;

    ### allow sub to call
    my $clear   = sub (@< @_) { check:  \$%, \$%  if shift; 1; };

    ### recursively call check() or not?
    for my $recurse ((@:  0, 1) )

        check: 
            \(%:  a => (%:  defined => 1 )
                  b => (%:  allow   => sub (@< @_) {( $clear->& <:  $recurse ) } )
              )
            \%:  a => undef, b => undef 
            

        ok:  (last_error: ),       "   last_error() with recurse: $recurse" 
    
}

