#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use Test::More tests => 18

BEGIN { $^WARNING = 1; }

my $warnings = ''
local $^WARN_HOOK = sub (@< @_) { $warnings .= @_[0]->message: }

my $TB = Test::Builder->new: 
sub no_warnings
    $TB->is_eq: $warnings, '', '  no warnings'
    $warnings = ''


sub warnings_is
    $TB->is_eq: $warnings, @_[0]
    $warnings = ''


sub warnings_like
    $TB->like: $warnings, "/@_[0]/"
    $warnings = ''



my $Filename = quotemeta $^PROGRAM_NAME


is:  undef, undef,           'undef is undef'
(no_warnings: )

isnt:  undef, 'foo',         'undef isnt foo'
(no_warnings: )

(isnt:  undef, '',            'undef isnt an empty string' );
(isnt:  undef, 0,             'undef isnt zero' );

#line 45
(like:  undef, '/.*/',        'undef is like anything' )
(warnings_like: qr/Use of uninitialized value.*/)

eq_array:  \(@: undef, undef), \(@: undef, 23) 
(no_warnings: )

eq_hash:  \(%:  foo => undef, bar => undef )
          \(%:  foo => undef, bar => 23 ) 
(no_warnings: )

eq_set:  \(@: undef, undef, 12), \(@: 29, undef, undef) 
(no_warnings: )


eq_hash:  \(%:  foo => undef, bar => \(%:  baz => undef, moo => 23 ) )
          \(%:  foo => undef, bar => \(%:  baz => undef, moo => 23 ) ) 
(no_warnings: )


#line 64
cmp_ok:  undef, '+<=', 2, '  undef +<= 2' 
warnings_like: qr/Use of uninitialized value.*/



my $tb = Test::More->builder: 

my $caught
open: *CATCH, '+<', \$caught or die: 
my $old_fail = $tb->failure_output
$tb->failure_output: \*CATCH
diag: undef
$tb->failure_output: $old_fail

is:  $caught, "# undef\n" 
(no_warnings: )

$caught = ""
$tb->maybe_regex: undef
is:  $caught, '' 
(no_warnings: )
