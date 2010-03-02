#!/usr/bin/perl

use Config
use ExtUtils::Embed
use File::Spec

(open: my $fh, ">","embed_test.c") || die: "Cannot open embed_test.c:$^OS_ERROR"
print: $fh, ~< $^DATA
close: $fh

$^OUTPUT_AUTOFLUSH = 1
print: $^STDOUT, "1..9\n"
my $cc = config_value: 'cc'
my $cl  = ($^OS_NAME eq 'MSWin32' && $cc eq 'cl')
my $borl  = ($^OS_NAME eq 'MSWin32' && $cc eq 'bcc32')
my $skip_exe = $^OS_NAME eq 'os2' && (config_value: "ldflags") =~ m/(?<!\S)-Zexe\b/
my $exe = 'embed_test'
$exe .= (config_value: 'exe_ext') unless $skip_exe        # Linker will auto-append it
my $obj = 'embed_test' . config_value: 'obj_ext'
my $inc = File::Spec->updir
my $lib = File::Spec->updir
my $libperl_copied
my $testlib
my @cmd
my (@cmd2) if $^OS_NAME eq 'VMS'
# Don't use ccopts() here as we may want to overwrite an existing
# perl with a new one with inconsistent header files, meaning
# the usual value for perl_inc(), which is used by ccopts(),
# will be wrong.
if ($^OS_NAME eq 'VMS')
    push: @cmd,$cc,"/Obj=$obj"
    my (@: @incs) =@:  (@: $inc)
    my $crazy = (ccflags: )
    if ($crazy =~ s#/inc[^=/]*=([\w\$\_\-\.\[\]\:]+)##i)
        push: @incs,$1
    
    if ($crazy =~ s/-I([a-zA-Z0-9\$\_\-\.\[\]\:]*)//)
        push: @incs,$1
    
    $crazy =~ s#/Obj[^=/]*=[\w\$\_\-\.\[\]\:]+##i
    push: @cmd,"/Include=(".(join: ',', @incs).")"
    push: @cmd,$crazy
    push: @cmd,"embed_test.c"

    push: @cmd2,(config_value: 'ld'), (config_value: 'ldflags'), "/exe=$exe"
    push: @cmd2,"$obj,[-]perlshr.opt/opt,[-]perlshr_attr.opt/opt"

else
    if ($cl)
        push: @cmd,$cc,"-Fe$exe"
    elsif ($borl)
        push: @cmd,$cc,"-o$exe"
    else
        push: @cmd,$cc,'-o' => $exe
    
    if ($^OS_NAME eq 'dec_osf' && !defined (config_value: "usedl"))
        # The -non_shared is needed in case of -Uusedl or otherwise
        # the test application will try to use libperl.so
        # instead of libperl.a.
        push: @cmd, "-non_shared"
    

    push: @cmd,"-I$inc", (ccflags: ),'embed_test.c'
    if ($^OS_NAME eq 'MSWin32')
        $inc = File::Spec->catdir: $inc,'win32'
        push: @cmd,"-I$inc"
        $inc = File::Spec->catdir: $inc,'include'
        push: @cmd,"-I$inc"
        if ($cc eq 'cl')
            push: @cmd,'-link',"-libpath:$lib"
                  (config_value: 'libperl'),(config_value: 'libs')
        else
            push: @cmd,"-L$lib"
                  (File::Spec->catfile: $lib, (config_value: 'libperl'))
                  (config_value: 'libc')
        
    elsif ($^OS_NAME eq 'os390' && (config_value: 'usedl')) {
    # Nothing for OS/390 (z/OS) dynamic.
    }else # Not MSWin32 or OS/390 (z/OS) dynamic.
        push: @cmd,"-L$lib",'-lperl'
        local $^WARN_HOOK = sub (@< @_)
            print: $^STDERR, @_[0]->message unless @_[0]->message =~ m/No library found for .*perl/
        
        push: @cmd, '-Zlinker', '/PM:VIO'	# Otherwise puts a warning to STDOUT!
            if $^OS_NAME eq 'os2' and (config_value: 'ldflags') =~ m/(?<!\S)-Zomf\b/
        push: @cmd, (ldopts: )
    
    if ($borl)
        @cmd = @: @cmd[0],(< (grep: {m/^-[LI]/},@cmd[[1..((nelems @cmd)-1)]])),(< (grep: {!m/^-[LI]/},@cmd[[1..((nelems @cmd)-1)]]))
    

    if ($^OS_NAME eq 'aix') # AIX needs an explicit symbol export list.
        my (@: $perl_exp) =  grep: { -f }, qw(perl.exp ../perl.exp)
        die: "where is perl.exp?\n" unless defined $perl_exp
        for ( @cmd)
            s!-bE:(\S+)!-bE:$perl_exp!
        
    elsif ($^OS_NAME eq 'cygwin') # Cygwin needs the shared libperl copied
        my $v_e_r_s = substr: (config_version: 'version'),0,-2
        $v_e_r_s =~ s/[.]/_/g
        system: "cp ../cygperl$v_e_r_s.dll ./"    # for test 1
    elsif ((config_value: 'libperl') !~ m/\Alibperl\./)
        # Everyone needs libperl copied if it's not found by '-lperl'.
        $testlib = config_value: 'libperl'
        my $srclib = $testlib
        $testlib =~ s/.+(?=\.[^.]*)/libperl/
        $testlib = File::Spec->catfile: $lib, $testlib
        $srclib = File::Spec->catfile: $lib, $srclib
        if (-f $srclib)
            unlink: $testlib if -f $testlib
            my $ln_or_cp = (config_value: 'ln') || config_value: 'cp'
            my $lncmd = "$ln_or_cp $srclib $testlib"
            #print "# $lncmd\n";
            $libperl_copied = 1	unless system: $lncmd
        
    

my $status
# On OS/2 the linker will always emit an empty line to STDOUT; filter these
my $cmd = join: ' ', @cmd
chomp: $cmd # where is the newline coming from? ldopts()?
print: $^STDOUT, "# $cmd\n"
my @out = @:  `$cmd` 
$status = $^CHILD_ERROR
foreach (@out)
    print: $^STDOUT, "# $_\n"

if ($^OS_NAME eq 'VMS' && !$status)
    print: $^STDOUT, "# $((join: ' ',@cmd2))\n"
    $status = system: (join: ' ', @cmd2)

print: $^STDOUT, ($status?? 'not '!! '')."ok 1\n"

my $embed_test = File::Spec->catfile: File::Spec->curdir, $exe
$embed_test = "run/nodebug $exe" if $^OS_NAME eq 'VMS'
print: $^STDOUT, "# embed_test = $embed_test\n"
$status = system: $embed_test
print: $^STDOUT, ($status?? 'not '!!'')."ok 9 # system returned $status\n"
unlink: $exe,"embed_test.c",$obj
unlink: "$exe.manifest" if $cl and (config_value: 'ccversion') =~ m/^(\d+)/ and $1 +>= 14
unlink: "$exe" . (config_value: "exe_ext") if $skip_exe
unlink: "embed_test.map","embed_test.lis" if $^OS_NAME eq 'VMS'
unlink: (glob:  <"./*.dll" if $^OS_NAME eq 'cygwin'
unlink: $testlib	       if $libperl_copied

# gcc -g -I.. -L../ -o perl_test perl_test.c -lperl `../perl -I../lib -MExtUtils::Embed -I../ -e ccflags -e ldopts`
__END__

/* perl_test.c */

#include <EXTERN.h>
#include <perl.h>

#define my_puts(a) if(puts(a) < 0) exit(666)

static const char * cmds [] = { "perl", "-e", "$^OUTPUT_AUTOFLUSH=1; print $^STDOUT, qq[ok 5\\n]", NULL };

#ifdef PERL_GLOBAL_STRUCT_PRIVATE
static struct perl_vars *my_plvarsp;
struct perl_vars* Perl_GetVarsPrivate(void) { return my_plvarsp; }
#endif

#ifdef NO_ENV_ARRAY_IN_MAIN
int main(int argc, char **argv) {
    char **env;
#else
int main(int argc, char **argv, char **env) {
#endif
    PerlInterpreter *my_perl;
#ifdef PERL_GLOBAL_STRUCT
    dVAR;
    struct perl_vars *plvarsp = init_global_struct();
#  ifdef PERL_GLOBAL_STRUCT_PRIVATE
    my_vars = my_plvarsp = plvarsp;
#  endif
#endif /* PERL_GLOBAL_STRUCT */

    (void)argc; /* PERL_SYS_INIT3 may #define away their use */
    (void)argv;
    PERL_SYS_INIT3(&argc, &argv, &env);

    my_perl = perl_alloc();

    my_puts("ok 2");

    perl_construct(my_perl);

    my_puts("ok 3");

    perl_parse(my_perl, NULL, (sizeof(cmds)/sizeof(char *))-1, (char **)cmds, env);

    my_puts("ok 4");

    fflush(stdout);

    perl_run(my_perl);

    my_puts("ok 6");

    perl_destruct(my_perl);

    my_puts("ok 7");

    perl_free(my_perl);

#ifdef PERL_GLOBAL_STRUCT
    free_global_struct(plvarsp);
#endif /* PERL_GLOBAL_STRUCT */

    my_puts("ok 8");

    PERL_SYS_TERM();

    return 0;
}
