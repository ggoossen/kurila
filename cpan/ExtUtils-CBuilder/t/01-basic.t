#! perl -w

use Test::More
BEGIN { (plan: tests => 11) }

use ExtUtils::CBuilder
use File::Spec
ok: 1

# TEST doesn't like extraneous output
my $quiet = (env::var: 'PERL_CORE') && !env::var: 'HARNESS_ACTIVE'

my $b = ExtUtils::CBuilder->new: quiet => $quiet
ok: $b

ok: $b->have_compiler: 

my $source_file = File::Spec->catfile: 't', 'compilet.c'
do
    open: my $fh, ">", "$source_file" or die: "Can't create $source_file: $^OS_ERROR"
    print: $fh, "int boot_compilet(void) \{ return 1; \}\n"
    close $fh

ok: -e $source_file

my $object_file = $b->object_file: $source_file
ok: 1

is: $object_file, $b->compile: source => $source_file

my $lib_file = $b->lib_file: $object_file
ok: 1

my (@: $lib, @< @temps) =  $b->link: objects => $object_file
                                     module_name => 'compilet'
$lib =~ s/"|'//g
is: $lib_file, $lib

for ((@: $source_file, $object_file, $lib_file))
    s/"|'//g
    1 while unlink: 


my @words = $b->split_like_shell: ' foo bar'
if ($^OS_NAME eq 'MSWin32')
    is: (nelems @words), 1
    is: @words[0], ' foo bar'
    skip: 'No splitting in split_like_shell() on Win32'
else
    is: (nelems: @words), 2
    is: @words[0], 'foo'
    is: @words[1], 'bar'

