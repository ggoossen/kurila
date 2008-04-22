#!./perl

use TestInit;

use Test::More tests => 26;

BEGIN { $_ = 'foo'; }  # because Symbol used to clobber $_

use Symbol;

ok( $_ eq 'foo', 'check $_ clobbering' );


# First test gensym()
$sym1 = gensym;
ok( ref($sym1) eq 'GLOB', 'gensym() returns a GLOB' );

$sym2 = gensym;

ok( $sym1 \!= $sym2, 'gensym() returns a different GLOB' );

ungensym $sym1;

$sym1 = $sym2 = undef;

# Test geniosym()

use Symbol qw(geniosym);

$sym1 = geniosym;
is( (ref $sym1), 'IO::Handle', 'got an IO ref' );

$FOO = 'Eymascalar';
*FOO = $sym1;

cmp_ok( $sym1, '\==', *FOO{IO}, 'assigns into glob OK' );

is( $FOO, 'Eymascalar', 'leaves scalar alone' );

{
    local $^W=1;		# 5.005 compat.
    my $warn;
    local $^WARN_HOOK = sub { $warn .= @_[0]->{description} };
    readline *FOO;
    like( $warn, qr/unopened filehandle/, 'warns like an unopened filehandle' );
}

# Test qualify()
package foo;

use Symbol qw(qualify qualify_to_ref);  # must import into this package too

::ok( qualify("x") eq "foo::x",		'qualify() with a simple identifier' );
::ok( qualify("x", "FOO") eq "FOO::x",	'qualify() with a package' );
::ok( qualify("BAR::x") eq "BAR::x",
    'qualify() with a qualified identifier' );
::ok( qualify("STDOUT") eq "main::STDOUT",
    'qualify() with a reserved identifier' );
::ok( qualify("ARGV", "FOO") eq "main::ARGV",
    'qualify() with a reserved identifier and a package' );
::ok( qualify("_foo") eq "foo::_foo",
    'qualify() with an identifier starting with a _' );
::is( qualify("^FOO"), "main::\cFOO",
    'qualify() with an identifier starting with a ^' );

# Test qualify_to_ref()
{
    ::ok( \*{qualify_to_ref("x")} \== \*foo::x, 'qualify_to_ref() with a simple identifier' );
}

# test fetch_glob()

::ok( (ref Symbol::fetch_glob("x")) eq "GLOB", "fetch_glob returns a ref to a glob" );
::ok( Symbol::fetch_glob("x") \== \*foo::x, "fetch_glob with unqualified name" );
::ok( Symbol::fetch_glob("foo::x") \== \*foo::x, "fetch_glob with qualified name" );

# test stash()
::ok( (ref Symbol::stash("foo")) eq "HASH", "stash returns a ref to a hash" );

# glob_name

::is( Symbol::glob_name(*FOO), "foo::FOO", "glob_name");
::is( Symbol::glob_name(*main::FOO), "main::FOO", "glob_name");

# tests for delete_package
package main;
$Transient::variable = 42;
ok( exists %::{'Transient::'}, 'transient stash exists' );
ok( defined %Transient::{variable}, 'transient variable in stash' );
Symbol::delete_package('Transient');
ok( !exists %Transient::{variable}, 'transient variable no longer in stash' );
is( scalar(keys %Transient::), 0, 'transient stash is empty' );
ok( !exists %::{'Transient::'}, 'no transient stash' );
