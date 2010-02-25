### Module::Load test suite ###
BEGIN 
    push: $^INCLUDE_PATH, "t/to_load"


use Module::Load
use Test::More tests => 13


do
    my $mod = 'Must::Be::Loaded'
    my $file = Module::Load::_to_file: $mod,1

    try { (load: $mod) }

    is:  $^EVAL_ERROR, '', qq[Loading module '$mod'] 
    ok:  (defined: $^INCLUDED{?$file}), q[... found in $^INCLUDED] 


do
    my $mod = 'LoadMe.pl'
    my $file = Module::Load::_to_file: $mod

    try { (load: $mod) }

    is:  $^EVAL_ERROR, '', qq[Loading File '$mod'] 
    ok:  (defined: $^INCLUDED{?$file}), q[... found in $^INCLUDED] 


do
    my $mod = 'LoadIt'
    my $file = Module::Load::_to_file: $mod,1

    try { (load: $mod) }

    is:  $^EVAL_ERROR, '', qq[Loading Ambigious Module '$mod'] 
    ok:  (defined: $^INCLUDED{?$file}), q[... found in $^INCLUDED] 


do
    my $mod = 'ToBeLoaded'
    my $file = Module::Load::_to_file: $mod

    try { (load: $mod) }

    is:  $^EVAL_ERROR && ($^EVAL_ERROR->message: ), '', qq[Loading Ambigious File '$mod'] 
    ok:  (defined: $^INCLUDED{?$file}), q[... found in $^INCLUDED] 


### Test importing functions ###
do {   my $mod     = 'TestModule';
    my @funcs   = qw[func1 func2];

    try { (load: $mod, < @funcs) };
    is:  $^EVAL_ERROR, '', qq[Loaded exporter module '$mod'] ;

    for my $func ( @funcs)
        ok:  ($mod->can: $func),           "$mod -> can( $func )" 
        ok:  (__PACKAGE__->can: $func),    "we -> can ( $func )"  
    
}    
