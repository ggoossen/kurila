
use Test::More  'no_plan'

my $Class   = 'Module::Loaded'
my @Funcs   = qw[mark_as_loaded mark_as_unloaded is_loaded]
my $Mod     = 'Foo::Bar'.$^PID
my $Strict  = 'error'

### load the thing
do {   use_ok:  $Class ;
    can_ok:  $Class, < @Funcs ;
}

do {   ok:  !(is_loaded: $Mod),       "$Mod not loaded yet" ;
    ok:  (mark_as_loaded: $Mod),   "   $Mod now marked as loaded" ;
    is:  (is_loaded: $Mod), $^PROGRAM_NAME,    "   $Mod is loaded from $^PROGRAM_NAME" ;

    my $rv = eval "require $Mod; 1";
    ok:  $rv,                    "$Mod required" ;
    ok:  !$^EVAL_ERROR,                    "   require did not die" ;
}

### unload again
do {   ok:  (mark_as_unloaded: $Mod), "$Mod now marked as unloaded" ;
    ok:  !(is_loaded: $Mod),       "   $Mod now longer loaded" ;

    my $rv = eval "require $Mod; 1";
    ok:  !$rv,                   "$Mod require failed" ;
    ok:  $^EVAL_ERROR,                     "   require died" ;
    like:  $^EVAL_ERROR->{?description}, qr/locate/,       "       with expected error" ;
}

### check for an already loaded module
use error
do {   my $where = (is_loaded:  $Strict );
    ok:  $where,                 "$Strict loaded" ;
    ok:  (mark_as_unloaded:  $Strict )
         "   $Strict unloaded" ;

    ### redefining subs, quell warnings
    do {   local $^WARN_HOOK = sub {};
        my $rv = eval "require $Strict; 1";
        ok:  $rv,                "$Strict loaded again" ;
    };

    is:  (is_loaded:  $Strict ), $where
         "   $Strict is loaded" ;
}
