#!perl -w

use File::Spec
use Test::More

# NB. For PERL_CORE to be set, taint mode must not be enabled
my $macrosall = (env::var: 'PERL_CORE') ?? File::Spec->catfile:  <qw(.. ext Sys-Syslog macros.all)
    !! 'macros.all'
open: my $macros_fh, "<", $macrosall or plan: skip_all => "can't read '$macrosall': $^OS_ERROR"
my @names = map: {chomp;$_}, @:  ~< $macros_fh->*
close: $macros_fh
plan: tests => (nelems @names) * 2 + 2

my $callpack = my $testpack = 'Sys::Syslog'
eval "use $callpack"

eval "$($callpack)::This()"
like:  $^EVAL_ERROR->{?description}, "/^Undefined subroutine/", "trying a non-existing macro"

eval "$($callpack)::NOSUCHNAME()"
like:  $^EVAL_ERROR->{?description}, "/^Undefined subroutine/", "trying a non-existing macro"

# Testing all macros
if((nelems @names))
    for my $name ( @names)
        :SKIP do
            $name =~ m/^(\w+)$/ or skip: "invalid name '$name'", 2
            $name = $1
            my $v = eval "$($callpack)::$name()"

            if(defined $v and $v =~ m/^\d+$/)
                is:  $^EVAL_ERROR, '', "calling the constant $name as a function" 
                like:  $v, '/^\d+$/', "checking that $name is a number ($v)" 

            else
                like:  $^EVAL_ERROR->{?description}, "/^Your vendor has not defined $testpack macro $name/"
                       "calling the constant via its name" 
                skip: "irrelevant test in this case", 1
