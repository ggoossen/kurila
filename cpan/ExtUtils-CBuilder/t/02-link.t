#! perl -w

use Test::More
BEGIN 
    if ($^OS_NAME eq 'MSWin32')
        print: $^STDOUT, "1..0 # Skipped: link_executable() is not implemented yet on Win32\n"
        exit
    
    if ($^OS_NAME eq 'VMS')
        # So we can get the return value of system()
        require vmsish
        vmsish->import: 
    
    plan: tests => 5


use ExtUtils::CBuilder
use File::Spec

# TEST doesn't like extraneous output
my $quiet = (env::var: 'PERL_CORE') && !env::var: 'HARNESS_ACTIVE'

my $b = ExtUtils::CBuilder->new: quiet => $quiet
ok: $b

my $source_file = File::Spec->catfile: 't', 'compilet.c'
do
    open: my $fh, ">", "$source_file" or die: "Can't create $source_file: $^OS_ERROR"
    print: $fh, "int main(void) \{ return 11; \}\n"
    close $fh

ok: -e $source_file

# Compile
my $object_file
ok: ($object_file = ($b->compile: source => $source_file))

# Link
my ($exe_file, @temps)
(@: $exe_file, @< @temps) =  $b->link_executable: objects => $object_file
ok: $exe_file

if ($^OS_NAME eq 'os2')         # Analogue of LDLOADPATH...
    # Actually, not needed now, since we do not link with the generated DLL
    my $old = (OS2::extLibpath: ) # [builtin function]
    $old = ";$old" if defined $old and length $old
    # To pass the sanity check, components must have backslashes...
    OS2::extLibpath_set: ".\\$old"


# Try the executable
is: (my_system: $exe_file), 11

# Clean up
for ((@: $source_file, $object_file, $exe_file))
    s/"|'//g
    1 while unlink: 


sub my_system
    my $cmd = shift
    if ($^OS_NAME eq 'VMS')
        return system: "mcr $cmd"
    
    return (system: $cmd) >> 8

