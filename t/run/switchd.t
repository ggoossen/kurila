#!./perl -w

BEGIN { require "./test.pl"; }

# This test depends on t/lib/Devel/switchd.pm.

plan: tests => 2

my $r
my @tmpfiles = $@
END { (unlink: < @tmpfiles) }

my $filename = 'swdtest.tmp'
:SKIP do
    open: my $f, ">", "$filename"
        or skip:  "Can't write temp file $filename: $^OS_ERROR" 
    print: $f, <<'__SWDTEST__'
package Bar;
sub bar { @_[0] * @_[0] }
package Foo;
sub foo {
  my $s;
  $s += Bar::bar($_) for 1..@_[0];
}
package main;
Foo::foo(3);
__SWDTEST__
    close $f
    push: @tmpfiles, $filename
    $^OUTPUT_AUTOFLUSH = 1 # Unbufferize.
    $r = runperl: 
        switches => \(@:  '-Ilib', '-I../lib', '-f', '-d:switchd' )
        progfile => $filename
        args => \(@: '3')
        
    like: $r, qr/^import<Devel::switchd>;$/
    $r = runperl: 
        switches => \(@:  '-Ilib', '-I../lib', '-f', '-d:switchd=a,42' )
        progfile => $filename
        args => \(@: '4')
        
    like: $r, qr/^import<Devel::switchd a 42>;$/


