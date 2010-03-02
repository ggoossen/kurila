#!/usr/bin/perl -w

# Can't use Test.pm, that's a 5.005 thing.
package My::Test

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


unless( try { require File::Spec } )
    print: $^STDOUT, "1..0 # Skip Need File::Spec to run this test\n"
    exit 0


if( $^OS_NAME eq 'MacOS' )
    print: $^STDOUT, "1..0 # Skip exit status broken on Mac OS\n"
    exit 0


require Test::Builder
my $TB = Test::Builder->create
$TB->level: 0


package main

my $IsVMS = $^OS_NAME eq 'VMS'

print: $^STDOUT, "# Ahh!  I see you're running VMS.\n" if $IsVMS

my %Tests = %:
    #                      Everyone Else   VMS
    'success.plx'              => (@: 0,      0)
    'one_fail.plx'             => (@: 1,      4)
    'two_fail.plx'             => (@: 2,      4)
    'five_fail.plx'            => (@: 5,      4)
    'extras.plx'               => (@: 2,      4)
    'too_few.plx'              => (@: 255,    4)
    'too_few_fail.plx'         => (@: 2,      4)
    'pre_plan_death.plx'       => (@: 'not zero',    'not zero')
    'death_in_eval.plx'        => (@: 0,      0)
    'require.plx'              => (@: 0,      0)
    'exit.plx'                 => (@: 1,      4)
    

$TB->plan:  tests => (nkeys: %Tests) 

try { require POSIX; (POSIX::WEXITSTATUS: 0) }
if( $^EVAL_ERROR )
    *exitstatus = sub (@< @_) { @_[0] >> 8 }
else
    *exitstatus = sub (@< @_) { (POSIX::WEXITSTATUS: @_[0]) }


chdir 't'
my $lib = File::Spec->catdir:  <qw(lib Test Simple sample_tests)
while( my(@: ?$test_name, ?$exit_codes) =(@:  each %Tests) )
    my $exit_code = $exit_codes[$IsVMS ?? 1 !! 0]

    my $Perl = $^EXECUTABLE_NAME

    if( $^OS_NAME eq 'VMS' )
        # Quiet noisy 'SYS$ABORT'.  'hushed' only exists in 5.6 and up,
        # but it doesn't do any harm on eariler perls.
        $Perl .= q{ -"Mvmsish=hushed"}
    

    my $file = File::Spec->catfile: $lib, $test_name
    my $wait_stat = system: qq{$Perl -"I../blib/lib" -"I../lib" -"I../t/lib" $file}
    my $actual_exit = exitstatus: $wait_stat

    if ($test_name =~ m/last_minute_death/)
        $TB->todo_skip: 'last minute death ignored'
    elsif( $exit_code eq 'not zero' )
        $TB->isnt_num:  $actual_exit, 0
                        "$test_name exited with $actual_exit ".
                            "(expected $exit_code)"
    else
        $TB->is_num:  $actual_exit, $exit_code
                      "$test_name exited with $actual_exit ".
                          "(expected $exit_code)"
    

