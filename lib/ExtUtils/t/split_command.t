#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


chdir 't'

use ExtUtils::MM
use MakeMaker::Test::Utils

my $Is_VMS   = $^OS_NAME eq 'VMS'
my $Is_Win32 = $^OS_NAME eq 'MSWin32'

use Test::More tests => 7

my $perl = (which_perl: )
my $mm = bless: \(%:  NAME => "Foo" ), "MM"

# I don't expect anything to have a length shorter than 256 chars.
cmp_ok:  ($mm->max_exec_len: ), '+>=', 256,   'max_exec_len' 

my $echo = $mm->oneliner: q{print: $^STDOUT, <@ARGV, qq[\n]}

# Force a short command length to make testing split_command easier.
$mm->{_MAX_EXEC_LEN} = (length: $echo) + 15
is:  ($mm->max_exec_len: ), $mm->{_MAX_EXEC_LEN}, '  forced a short max_exec_len' 

my @test_args = qw(foo bar baz yar car har ackapicklerootyjamboree)
my @cmds = $mm->split_command: $echo, < @test_args
isnt:  (nelems @cmds), 0 

my @results = _run: < @cmds
is:  (join: '', @results), (join: '', @test_args)


my %test_args = %:  foo => 42, bar => 23, car => 'har' 
my $even_args = $mm->oneliner: q{print: $^STDOUT, !((nelems @ARGV) % 2)}
@cmds = $mm->split_command: $even_args, < %test_args
isnt:  (nelems @cmds), 0 

@results = _run: < @cmds
like:  (join: '', @results ), qr/^1+$/,         'pairs preserved' 

is:  (nelems ($mm->split_command: $echo)), 0,  'no args means no commands' 


sub _run
    my @cmds = @_

    foreach (@cmds)
        s{\$\(ABSPERLRUN\)}{$perl}
    if( $Is_VMS )
        foreach (@cmds)
            s{-\n}{}
    elsif( $Is_Win32 )
        foreach (@cmds)
            s{\\\n}{}

    return map: { s/\n+$//; $_ }, map: { `$_` }, @cmds
