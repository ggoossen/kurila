#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


chdir 't'

use MakeMaker::Test::Utils
use Test::More tests => 6
use File::Spec

my $TB = Test::More->builder: 

BEGIN { (use_ok: 'ExtUtils::MM') }

my $mm = bless: \(%:  NAME => "Foo" ), 'MM'
isa_ok: $mm, 'ExtUtils::MakeMaker'
isa_ok: $mm, 'ExtUtils::MM_Any'


sub try_oneliner
    my(@: $code, $switches, $expect, $name) =  @_
    my $cmd = $mm->oneliner: $code, $switches
    $cmd =~ s{\$\(ABSPERLRUN\)}{$^EXECUTABLE_NAME}

    # VMS likes to put newlines at the end of commands if there isn't
    # one already.
    $expect =~ s/([^\n])\z/$1\n/ if $^OS_NAME eq 'VMS'

    ($TB->is_eq: scalar `$cmd`, $expect, $name) || $TB->diag: "oneliner:\n$cmd"


# Lets see how it deals with quotes.
try_oneliner: q{print: $^STDOUT, "foo'o", ' bar"ar'}, $@,  q{foo'o bar"ar},  'quotes'

# How about dollar signs?
try_oneliner: q{our $PATH = 'foo'; print: $^STDOUT, $PATH}, $@, q{foo},   'dollar signs' 

# switches?
try_oneliner: q{print: $^STDOUT, $^INPUT_RECORD_SEPARATOR}, (@: '-0'),           "\0",       'switches' 

# XXX gotta rethink the newline test.  The Makefile does newline
# escaping, then the shell.

