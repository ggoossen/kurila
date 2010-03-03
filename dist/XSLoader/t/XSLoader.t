#!/usr/bin/perl


use Config

BEGIN 
    eval "use Test::More"
    if ($^EVAL_ERROR)
        print: $^STDOUT, "1..0 # Skip: Test::More not available\n"
        die: "Test::More not available\n"

    use Config


my %modules = %:
    # ModuleName  => q|code to check that it was loaded|,
    'Cwd'        => q| main::can_ok( 'Cwd' => 'fastcwd'         ) |
    'File::Glob' => q| main::can_ok( 'File::Glob' => 'doglob'   ) |
    'Socket'     => q| main::can_ok( 'Socket' => 'inet_aton'    ) |
    'Time::HiRes'=> q| main::can_ok( 'Time::HiRes' => 'usleep'  ) |
    

plan: tests => (nelems: (keys: %modules)) * 3 + 5

# Try to load the module
use_ok:  'XSLoader' 

# Check functions
can_ok:  'XSLoader' => 'load' 
can_ok:  'XSLoader' => 'bootstrap_inherit' 

# Check error messages
eval "XSLoader::load: "
like:  $^EVAL_ERROR->{?description}, qr/Not enough arguments for XSLoader::load/
       "calling XSLoader::load() with no argument"

eval q{ package Thwack; XSLoader::load('Thwack'); }
like:  $^EVAL_ERROR->message, q{/^Can't locate loadable object for module Thwack in \$\^INCLUDE_PATH/}
       "calling XSLoader::load() under a package with no XS part" 

# Now try to load well known XS modules
my $extensions = config_value: 'extensions'
$extensions =~ s|/|::|g

for my $module ((sort: keys %modules))
    :SKIP do
        skip: "$module not available", 3 if $extensions !~ m/\b$module\b/

        eval: qq{ package $module; XSLoader::load: '$module', "qunckkk"; }
        like: $^EVAL_ERROR->message, "/^$module object version \\S+ does not match bootstrap parameter (?:qunckkk|0)/"
              "calling XSLoader::load() with a XS module and an incorrect version" 

        eval qq{ package $module; XSLoader::load('$module'); }
        is:  $^EVAL_ERROR, '',  "XSLoader::load($module)"

        eval qq{ package $module; %modules{?$module}; }
        die: if $^EVAL_ERROR
    


