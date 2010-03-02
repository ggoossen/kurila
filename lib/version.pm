#!perl -w
package version

our (@ISA, $VERSION, $CLASS)

$VERSION = 0.73

$CLASS = 'version'

# Preloaded methods go here.
sub import($class, ...)
    my $callpkg = (caller: )

    (Symbol::fetch_glob: $callpkg."::qv")->* =
        sub (@< @_) {return (bless: (version::qv: shift), $class) }
        unless exists: (Symbol::fetch_glob: "$callpkg\::qv")->&


1
