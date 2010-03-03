#!./perl

BEGIN 
    $^OUTPUT_AUTOFLUSH = 1
    $^WARN_HOOK = sub (@< @_) { (die: "Dying on warning: ", < @_) }


BEGIN 
    require "./test.pl"


use warnings
use Config

plan: tests => 28


my $Is_MSWin32  = $^OS_NAME eq 'MSWin32'
my $Is_NetWare  = $^OS_NAME eq 'NetWare'
my $Is_VMS      = $^OS_NAME eq 'VMS'
my $Is_Dos      = $^OS_NAME eq 'dos'
my $Is_os2      = $^OS_NAME eq 'os2'
my $Is_Cygwin   = $^OS_NAME eq 'cygwin'
my $Is_MacOS    = $^OS_NAME eq 'MacOS'
my $Is_MPE      = $^OS_NAME eq 'mpeix'
my $Is_miniperl = env::var: 'PERL_CORE_MINITEST'
my $Is_BeOS     = $^OS_NAME eq 'beos'

my $PERL = env::var: 'PERL'
    || ($Is_NetWare           ?? 'perl'   !!
        ($Is_MacOS || $Is_VMS) ?? $^EXECUTABLE_NAME      !!
        $Is_MSWin32            ?? '.\perl' !!
        './perl')

eval 'env::var("FOO") = "hi there";'	# check that ENV is inited inside eval
# cmd.exe will echo 'variable=value' but 4nt will echo just the value
# -- Nikola Knezevic
if ($Is_MSWin32)  { ok: `set FOO` =~ m/^(?:FOO=)?hi there$/; }
    elsif ($Is_MacOS) { ok: "1 # skipped", 1; }
    elsif ($Is_VMS)   { ok: `write sys\$output f\$trnlnm("FOO")` eq "hi there\n"; }
else              { ok: `echo \$FOO` eq "hi there\n"; }

unlink: 'ajslkdfpqjsjfk'
$^OS_ERROR = 0
open: my $foo, "<",'ajslkdfpqjsjfk'
ok: $^OS_ERROR, $^OS_ERROR
close $foo # just mention it, squelch used-only-once

# regex vars

# $?, $@, $$
if ($Is_MacOS)
    skip: '$? + system are broken on MacPerl', 2
else
    system: qq[$PERL "-I../lib" -e "use vmsish qw(hushed); exit(0)"]
    ok: $^CHILD_ERROR == 0, '$?'
    system: qq[$PERL "-I../lib" -e "use vmsish qw(hushed); exit(1)"]
    ok: $^CHILD_ERROR != 0, '$?'


try { (die: "foo\n") }
ok: $^EVAL_ERROR->{?description} eq "foo\n", '$@'

ok: $^PID +> 0, $^PID
try { $^PID++ }

like: $^EVAL_ERROR->{?description}, qr/^Modification of the read-only magic variable \$\^PID attempted/

our ($wd, $script)

# $^X and $0
do
    if ($^OS_NAME eq 'qnx')
        chomp: ($wd = `/usr/bin/fullpath -t`)
    elsif($Is_Cygwin || (config_value: 'd_procselfexe'))
        # Cygwin turns the symlink into the real file
        chomp: ($wd = `pwd`)
        $wd =~ s#/t$##
        if ($Is_Cygwin)
            $wd = Cygwin::win_to_posix_path:  <(Cygwin::posix_to_win_path: $wd, 1)
        
    elsif($Is_os2)
        $wd = (Cwd::sys_cwd: )
    elsif($Is_MacOS)
        $wd = ':'
    else
        $wd = '.'
    
    my $perl = ($Is_MacOS || $Is_VMS) ?? $^EXECUTABLE_NAME !! "$wd/perl"
    my $headmaybe = ''
    my $middlemaybe = ''
    my $tailmaybe = ''
    $script = "$wd/show-shebang"
    if ($Is_MSWin32)
        chomp: ($wd = `cd`)
        $wd =~ s|\\|/|g
        $perl = "$wd/perl.exe"
        $script = "$wd/show-shebang.bat"
        $headmaybe = <<EOH 
\@rem ='
\@echo off
$perl -x \%0
goto endofperl
\@rem ';
EOH
        $tailmaybe = <<EOT 

__END__
:endofperl
EOT
    elsif ($Is_os2)
        $script = "./show-shebang"
    elsif ($Is_MacOS)
        $script = ":show-shebang"
    elsif ($Is_VMS)
        $script = "[]show-shebang"
    elsif ($Is_Cygwin)
        $middlemaybe = <<'EOX'
$^EXECUTABLE_NAME = Cygwin::win_to_posix_path(Cygwin::posix_to_win_path($^EXECUTABLE_NAME, 1));
$^PROGRAM_NAME = Cygwin::win_to_posix_path(Cygwin::posix_to_win_path($^PROGRAM_NAME, 1));
EOX
    
    if ($^OS_NAME eq 'os390' or $^OS_NAME eq 'posix-bc' or $^OS_NAME eq 'vmesa')  # no shebang
        $headmaybe = <<EOH 
    eval 'exec ./perl -S \$0 \$\{1+"\$\@"\}'
        if 0;
EOH
    
    my $s1 = "\$^EXECUTABLE_NAME is $perl, \$^PROGRAM_NAME is $script\n"
    ok: (open: my $script_fh, ">", "$script"), '$!'
    ok: (print: $script_fh, $headmaybe . <<EOB . $middlemaybe . <<'EOF' . $tailmaybe), '$!'
#!$wd/perl
EOB
print: $^STDOUT, "\$^EXECUTABLE_NAME is $^EXECUTABLE_NAME, \$^PROGRAM_NAME is $^PROGRAM_NAME\n";
EOF
    ok: (close: $script_fh), '$!'
    ok: (chmod: 0755, $script), '$!'
    $_ = ($Is_MacOS || $Is_VMS) ?? `$perl $script` !! `$script`
    s/\.exe//i if $Is_Dos or $Is_Cygwin or $Is_os2
    s{./$script}{$script} if $Is_BeOS # revert BeOS execvp() side-effect
    s{\bminiperl\b}{perl} # so that test doesn't fail with miniperl
    s{is perl}{is $perl} # for systems where $^X is only a basename
    s{\\}{/}g
    ok: (($Is_MSWin32 || $Is_os2) ?? (uc: $_) eq (uc: $s1) !! $_ eq $s1), ' :$_:!=:$s1:'
    $_ = `$perl $script`
    s/\.exe//i if $Is_Dos or $Is_os2 or $Is_Cygwin
    s{./$perl}{$perl} if $Is_BeOS # revert BeOS execvp() side-effect
    s{\\}{/}g
    ok: ($Is_MSWin32 || $Is_os2) ?? (uc: $_) eq (uc: $s1) !! $_ eq $s1 or diag: " :$_:!=:$s1: after `$perl $script`"
    ok: (unlink: $script) or diag: $^OS_ERROR


# $], $^O, $^T
ok: $^OS_NAME
ok: $^BASETIME +> 850000000, $^BASETIME

if ($Is_VMS || $Is_Dos || $Is_MacOS)
    skip: "\%ENV manipulations fail or aren't safe on $^OS_NAME", 4
else
    if ((env::var: 'PERL_VALGRIND'))
        skip: "clearing \%ENV is not safe when running under valgrind"
    else
        my $PATH = env::var: 'PATH'
        my $PDL = (env::var: 'PERL_DESTRUCT_LEVEL') || 0
        (env::var: 'foo' ) = "bar"
        for ((env::keys: ))
            (env::var: $_) = undef
        
        (env::var: 'PATH' ) = $PATH
        (env::var: 'PERL_DESTRUCT_LEVEL' ) = $PDL || 0
        ok: $Is_MSWin32 ?? (`set foo 2>NUL` eq "")
                !! (`echo \$foo` eq "\n") 
    

    (env::var: '__NoNeSuCh' ) = "foo"
    $^PROGRAM_NAME = "bar"
    # cmd.exe will echo 'variable=value' but 4nt will echo just the value
    # -- Nikola Knezevic
    ok: $Is_MSWin32 ?? (`set __NoNeSuCh` =~ m/^(?:__NoNeSuCh=)?foo$/)
            !! (`echo \$__NoNeSuCh` eq "foo\n") 
    if ($^OS_NAME =~ m/^(linux|freebsd)$/ &&
        open: my $cmdline, '<', "/proc/$^PID/cmdline")
        chomp: (my $line = scalar ~< $cmdline)
        my $me = ((split: m/\0/, $line))[0]
        ok: $me eq $^PROGRAM_NAME, 'altering $0 is effective (testing with /proc/)'
        close $cmdline
        # perlbug #22811
        my $mydollarzero = sub (@< @_)
            my(@: $arg) =@:  shift
            $^PROGRAM_NAME = $arg if defined $arg
            # In FreeBSD the ps -o command= will cause
            # an empty header line, grab only the last line.
            my $ps = (@: `ps -o command= -p $^PID`)[-1]
            return if $^CHILD_ERROR
            chomp $ps
            printf: $^STDOUT, "# 0[\%s]ps[\%s]\n", $^PROGRAM_NAME, $ps
            $ps
        
        my $ps = $mydollarzero->& <: "x"
        ok: !$ps  # we allow that something goes wrong with the ps command
           # In Linux 2.4 we would get an exact match ($ps eq 'x') but
           # in Linux 2.2 there seems to be something funny going on:
           # it seems as if the original length of the argv[] would
           # be stored in the proc struct and then used by ps(1),
           # no matter what characters we use to pad the argv[].
           # (And if we use \0:s, they are shown as spaces.)  Sigh.
               || $ps =~ m/^x\s*$/
           # FreeBSD cannot get rid of both the leading "perl :"
           # and the trailing " (perl)": some FreeBSD versions
           # can get rid of the first one.
               || ($^OS_NAME eq 'freebsd' && $ps =~ m/^(?:perl: )?x(?: \(perl\))?$/)
            'altering $0 is effective (testing with `ps`)'
    else
        skip: "\$0 check only on Linux and FreeBSD", 2
    


do
    my $ok = 1
    my $warn = ''
    local $^WARN_HOOK = sub (@< @_) { $ok = 0; $warn = (join: '', @_); }
    $^OS_ERROR = undef
    ok: $ok, $warn, $Is_VMS ?? "'\$!=undef' does throw a warning" !! ''


:SKIP do
    # test case-insignificance of %ENV (these tests must be enabled only
    # when perl is compiled with -DENV_IS_CASELESS)
    skip: 'no caseless %ENV support', 3 unless $Is_MSWin32 || $Is_NetWare
    for ((env::keys: ))
        (env::var: $_) = undef
    
    (env::var: 'Foo' ) = 'bar'
    (env::var: 'fOo' ) = 'baz'
    ok: (nelems: (env::keys: )) == 1
    ok: defined: (env::var: 'FOo')
    (env::var: 'foO') = undef
    ok: (nelems: (env::keys: )) == 0


ok: $^EXCEPTIONS_BEING_CAUGHT == 0 && defined $^EXCEPTIONS_BEING_CAUGHT
try { (ok: $^EXCEPTIONS_BEING_CAUGHT == 1) }
eval " BEGIN \{ ok ! defined \$^S \} "
ok: $^EXCEPTIONS_BEING_CAUGHT == 0 && defined $^EXCEPTIONS_BEING_CAUGHT

# Test for bug [perl #36434]
do
    our @ISA
    local @ISA
    # This used to be __PACKAGE__, but that causes recursive
    #  inheritance, which is detected earlier now and broke
    #  this test
    try { (push: @ISA, __FILE__ )}
    ok:  $^EVAL_ERROR eq '', 'Push a constant on a magic array'
    $^EVAL_ERROR and print: "# $^EVAL_ERROR"

