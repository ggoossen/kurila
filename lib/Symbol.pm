package Symbol

=head1 NAME

Symbol - manipulate Perl symbols and their names

=head1 SYNOPSIS

    print ${*{Symbol::fetch_glob("$class\::VERSION")}};
    *{Symbol::fetch_glob("foo") = sub { "this is foo" };

    keys %{Symbol::stash("main")};

    use Symbol;

    $sym = gensym;
    open($sym, "filename");
    $_ = <$sym>;
    # etc.

    ungensym $sym;      # no effect

    # replace *FOO{IO} handle but not $FOO, %FOO, etc.
    *FOO = geniosym;

    print qualify("x"), "\n";              # "Test::x"
    print qualify("x", "FOO"), "\n"        # "FOO::x"
    print qualify("BAR::x"), "\n";         # "BAR::x"
    print qualify("BAR::x", "FOO"), "\n";  # "BAR::x"
    print qualify("STDOUT", "FOO"), "\n";  # "main::STDOUT" (global)
    print qualify(\*x), "\n";              # returns \*x
    print qualify(\*x, "FOO"), "\n";       # returns \*x

    print { qualify_to_ref $fh } "foo!\n";
    $ref = qualify_to_ref $name, $pkg;

    use Symbol qw(delete_package);
    delete_package('Foo::Bar');
    print "deleted\n" unless exists $Foo::{'Bar::'};

=head1 DESCRIPTION

C<Symbol::fetch_glob> returns a reference to the glob for the
specified symbol name. If the symbol does not already exists it will
be created. If the symbol name is unqualified it will be looked up in
the calling package.

C<Symbol::stash> returns a refernce to the stash for the specified
name. If the stash does not already exists it will be created. The
name of the stash does not include the "::" at the end.

C<Symbol::gensym> creates an anonymous glob and returns a reference
to it.  Such a glob reference can be used as a file or directory
handle.

For backward compatibility with older implementations that didn't
support anonymous globs, C<Symbol::ungensym> is also provided.
But it doesn't do anything.

C<Symbol::geniosym> creates an anonymous IO handle.  This can be
assigned into an existing glob without affecting the non-IO portions
of the glob.

C<Symbol::qualify> turns unqualified symbol names into qualified
variable names (e.g. "myvar" -E<gt> "MyPackage::myvar").  If it is given a
second parameter, C<qualify> uses it as the default package;
otherwise, it uses the package of its caller.  Regardless, global
variable names (e.g. "STDOUT", "ENV", "SIG") are always qualified with
"main::".

Qualification applies only to symbol names (strings).  References are
left unchanged under the assumption that they are glob references,
which are qualified by their nature.

C<Symbol::qualify_to_ref> is just like C<Symbol::qualify> except that it
returns a glob ref rather than a symbol name, so you can use the result
even if C<use strict 'refs'> is in effect.

C<Symbol::delete_package> wipes out a whole package namespace.  Note
this routine is not exported by default--you may want to import it
explicitly.

=head1 BUGS

C<Symbol::delete_package> is a bit too powerful. It undefines every symbol that
lives in the specified package. Since perl, for performance reasons, does not
perform a symbol table lookup each time a function is called or a global
variable is accessed, some code that has already been loaded and that makes use
of symbols in package C<Foo> may stop working after you delete C<Foo>, even if
you reload the C<Foo> module afterwards.

=cut


require Exporter
our @ISA = qw(Exporter)
our @EXPORT = qw(gensym ungensym qualify qualify_to_ref)
our @EXPORT_OK = qw(delete_package geniosym)

our $VERSION = '1.06'

my $genpkg = "Symbol"
my $genseq = 0

my %global = %+: map: { %: $_ => 1 }, qw(ARGV ARGVOUT ENV INC SIG STDERR STDIN STDOUT) 

#
# Note that we never _copy_ the glob; we just make a ref to it.
# If we did copy it, then SVf_FAKE would be set on the copy, and
# glob-specific behaviors (e.g. C<*$ref = \&func>) wouldn't work.
#
sub gensym ()
    my $name = "GEN" . $genseq++
    my $ref = \(Symbol::qualify_to_ref: $genpkg . "::" . $name)->*
    $ref = \(Symbol::qualify_to_ref: $genpkg . "::" . $name)->*  # second time to supress only-used once warning.
    delete (Symbol::stash: $genpkg)->{$name}
    $ref


sub geniosym ()
    my $sym = (gensym: )
    # force the IO slot to be filled
    open: $sym
    $sym->*{IO}


sub ungensym(_) {}

sub qualify($name, ? $pkg)
    ref \$name eq "GLOB" and Carp::confess: "glob..." . ref $name
    if (!(ref: $name) && (index: $name, '::') == -1 && (index: $name, "'") == -1)
        # Global names: special character, "^xyz", or other.
        if ($name =~ m/^(([^a-z])|(\^[a-z_]+))\z/i || %global{?$name})
            $pkg = ""
        else
            $pkg //= caller
        
        $name = $pkg . "::" . $name
    
    $name


sub qualify_to_ref($name, ?$package)
    return \ (Symbol::fetch_glob:  (qualify: $name, (defined $package) ?? $package !! (scalar: caller)) )->*


#
# of Safe.pm lineage
#
sub delete_package($pkg)

    # expand to full symbol table name if needed

    unless ($pkg =~ m/^main::.*::$/)
        $pkg = "main$pkg"       if      $pkg =~ m/^::/
        $pkg .= '::'            unless  $pkg =~ m/::$/
    

    my (@: $stem, $leaf) = @: $pkg =~ m/(.*)::(\w+::)$/
    my $stem_symtab = Symbol::stash: $stem
    return unless defined $stem_symtab and exists $stem_symtab->{$leaf}


    # free all the symbols in the package

    my $leaf_symtab = $stem_symtab->{?$leaf}->{HASH}
    foreach my $name (keys $leaf_symtab->%)
        undef (Symbol::qualify_to_ref: $pkg . $name)->*
    

    # delete the symbol table

    $leaf_symtab->% = $%
    delete $stem_symtab->{$leaf}


1
