#!./perl

use TestInit

use Test::More tests => 24

BEGIN { $_ = 'foo'; }  # because Symbol used to clobber $_

use Symbol

ok:  $_ eq 'foo', 'check $_ clobbering' 


# First test gensym()
our $sym1 = (gensym: )
ok:  (ref: $sym1) eq 'GLOB', 'gensym() returns a GLOB' 

our $sym2 = (gensym: )

ok:  $sym1 \!= $sym2, 'gensym() returns a different GLOB' 

ungensym: $sym1

$sym1 = $sym2 = undef

# Test geniosym()

use Symbol q(geniosym)

$sym1 = (geniosym: )
is:  (ref $sym1), 'IO::Handle', 'got an IO ref' 

our $FOO = 'Eymascalar'
*FOO = $sym1

cmp_ok:  $sym1, '\==', *FOO{IO}, 'assigns into glob OK' 

is:  $FOO, 'Eymascalar', 'leaves scalar alone' 

do
    local $^WARNING = 1		# 5.005 compat.
    my $warn
    local $^WARN_HOOK = sub (@< @_) { $warn .= @_[0]->{?description} }
    readline *FOOBAR
    like:  $warn, qr/unopened filehandle/, 'warns like an unopened filehandle' 


# Test qualify()
package foo

use Symbol < qw(qualify qualify_to_ref)  # must import into this package too

main::ok:  (qualify: "x") eq "foo::x",		'qualify() with a simple identifier' 
main::ok:  (qualify: "x", "FOO") eq "FOO::x",	'qualify() with a package' 
main::ok:  (qualify: "BAR::x") eq "BAR::x"
           'qualify() with a qualified identifier' 
main::ok:  (qualify: "STDOUT") eq "::STDOUT"
           'qualify() with a reserved identifier' 
main::ok:  (qualify: "ARGV", "FOO") eq "::ARGV"
           'qualify() with a reserved identifier and a package' 
main::ok:  (qualify: "_foo") eq "foo::_foo"
           'qualify() with an identifier starting with a _' 
main::is:  (qualify: "^FOO"), "::^FOO"
           'qualify() with an identifier starting with a ^' 

# Test qualify_to_ref()
do
    main::ok:  \(qualify_to_ref: "x")->* \== \*foo::x, 'qualify_to_ref() with a simple identifier' 
    main::is:  (qualify_to_ref: "FOO"), \*FOO
               'qualify_to_ref() with reserved indentier is the special variable' 


# test fetch_glob()

main::ok:  (ref (Symbol::fetch_glob: "x")) eq "GLOB", "fetch_glob returns a ref to a glob" 
main::ok:  (Symbol::fetch_glob: "x") \== \*foo::x, "fetch_glob with unqualified name" 
main::ok:  (Symbol::fetch_glob: "foo::x") \== \*foo::x, "fetch_glob with qualified name" 

# test stash()
main::ok:  (ref (Symbol::stash: "foo")) eq "HASH", "stash returns a ref to a hash" 

# glob_name

main::is:  (Symbol::glob_name: *FOO), "foo::FOO", "glob_name"
main::is:  (Symbol::glob_name: *main::FOO), "main::FOO", "glob_name"

# tests for delete_package
package main
:TODO do
    todo_skip: "fix delete_package", 2
    $Transient::variable = 42
    ok:  defined %Transient::{?variable}, 'transient variable in stash' 
    Symbol::delete_package: 'Transient'
    ok:  !exists %Transient::{variable}, 'transient variable no longer in stash' 
    is:  (nelems: (@: keys %Transient::)), 0, 'transient stash is empty' 

