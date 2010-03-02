#!./perl -w

BEGIN 
    require 'test.pl'


use Config
use File::Spec
use File::Path

my $path = File::Spec->catdir:  'lib', 'B' 
unless (-d $path)
    mkpath:  $path  or skip_all:  'Cannot create fake module path' 


my $file = File::Spec->catfile:  $path, 'success.pm' 
my $out_fh
open: $out_fh, '>', $file or skip_all:  'Cannot write fake backend module'
(print: $out_fh, $_) while ~< $^DATA
close $out_fh

plan:  9  # And someone's responsible.

# use() makes it difficult to avoid O::import()
require_ok:  'O' 

my @args = @: '-Ilib', '-MO=success,foo,bar', '-e', '1' 
my @lines = get_lines:  < @args 

is:  @lines[0], 'Compiling!', 'Output should not be saved without -q switch' 
is:  @lines[1], '(foo) <bar>', 'O.pm should call backend compile() method' 
is:  @lines[2], '[]', 'Nothing should be in $O::BEGIN_output without -q' 
is:  @lines[3], '-e syntax OK', 'O.pm should not munge perl output without -qq'

@args[1] = '-MO=-q,success,foo,bar'
@lines = get_lines:  < @args 
isnt:  @lines[1], 'Compiling!', 'Output should not be printed with -q switch' 

:SKIP do
    skip:  '-q redirection does not work without PerlIO', 2
        unless config_value: "useperlio"
    is:  @lines[1], "[Compiling!", '... but should be in $O::BEGIN_output' 

    @args[1] = '-MO=-qq,success,foo,bar'
    @lines = get_lines:  < @args 
    is:  scalar nelems @lines, 3, '-qq should suppress even the syntax OK message' 


@args[1] = '-MO=success,fail'
@lines = get_lines:  < @args 
like:  @lines[1], qr/Compilesub isn't CODE/
       'O.pm should die if backend compile() does not return a subref' 

sub get_lines { (split: m/[\r\n]+/, (runperl:  args => \ @_, stderr => 1 ));
}

END 
    1 while unlink: $file
    rmdir: $path # not "1 while" since there might be more in there


__END__
package B::success

$^OUTPUT_AUTOFLUSH = 1
print: $^STDOUT, "Compiling!\n"

sub compile($arg1, ?$arg2)
        return 'fail' if ($arg1 eq 'fail')
        print: $^STDOUT, "($arg1) <$arg2>\n"
        return sub { print: $^STDOUT, "[$O::BEGIN_output]\n" }

1
