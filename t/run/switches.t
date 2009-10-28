#!./perl -w

# Tests for the command-line switches:
# -0, -c, -l, -s, -m, -M, -V, -v, -h, -i, -E and all unknown
# Some switches have their own tests, see MANIFEST.

BEGIN
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @: '../lib'

BEGIN { require "./test.pl"; }

plan: tests => 55

use Config

# due to a bug in VMS's piping which makes it impossible for runperl()
# to emulate echo -n (ie. stdin always winds up with a newline), these
# tests almost totally fail.
our $TODO = "runperl() unable to emulate echo -n due to pipe bug" if $^OS_NAME eq 'VMS'

my $r
my @tmpfiles = $@
END { (unlink: < @tmpfiles) }

$r = runperl: 
    switches    => \$@
    stdin       => 'foo\nbar\nbaz\n'
    prog        => 'print $^STDOUT, qq(<$_>) while ~< *ARGV'
    
is:  $r, "<foo\n><bar\n><baz\n>", "no switches" 

# Tests for -0

$r = runperl: 
    switches    => \(@:  '-0', )
    stdin       => 'foo\0bar\0baz\0'
    prog        => 'print $^STDOUT, qq(<$_>) while ~< *ARGV'
    
is:  $r, "<foo\0><bar\0><baz\0>", "-0" 

$r = runperl: 
    switches    => \(@:  (sprintf: '-0%o', ord 'x') )
    stdin       => 'fooxbarxbazx'
    prog        => 'print $^STDOUT, qq(<$_>) while ~< *ARGV'
    
is:  $r, "<foox><barx><bazx>", "-0 with octal number" 

$r = runperl: 
    switches    => \(@:  '-066' )
    prog        => 'BEGIN { print $^STDOUT, qq{($^INPUT_RECORD_SEPARATOR)} } print $^STDOUT, qq{[$^INPUT_RECORD_SEPARATOR]}'
    
is:  $r, "(\066)[\066]", '$/ set at compile-time' 

# Tests for -c

my $filename = 'swctest.tmp'
:SKIP do
    local $TODO = ''   # this one works on VMS

    open: my $f, ">", "$filename" or skip:  "Can't write temp file $filename: $^OS_ERROR" 
    print: $f, <<'SWTEST'
BEGIN { print $^STDOUT, "block 1\n"; }
CHECK { print $^STDOUT, "block 2\n"; }
INIT  { print $^STDOUT, "block 3\n"; }
        print $^STDOUT, "block 4\n";
END   { print $^STDOUT, "block 5\n"; }
SWTEST
    close $f or die: "Could not close: $^OS_ERROR"
    $r = runperl: 
        switches        => \(@:  '-c' )
        progfile        => $filename
        stderr          => 1
        
    # Because of the stderr redirection, we can't tell reliably the order
    # in which the output is given
    ok: 
       $r =~ m/$filename syntax OK/
         && $r =~ m/\bblock 1\b/
         && $r =~ m/\bblock 2\b/
         && $r !~ m/\bblock 3\b/
         && $r !~ m/\bblock 4\b/
          && $r !~ m/\bblock 5\b/
       '-c'
       
    push: @tmpfiles, $filename


# Tests for -m and -M

$filename = 'swtest.pm'
:SKIP do
    open: my $f, ">", "$filename" or skip:  "Can't write temp file $filename: $^OS_ERROR",4 
    print: $f, <<'SWTESTPM'
package swtest;
sub import { print $^STDOUT, < map { "<$_>" }, @_ }
1;
SWTESTPM
    close $f or die: "Could not close: $^OS_ERROR"
    $r = runperl: 
        switches    => \(@:  '-Mswtest' )
        prog        => '1'
        
    is:  $r, '<swtest>', '-M' 
    $r = runperl: 
        switches    => \(@:  '-Mswtest=foo' )
        prog        => '1'
        
    is:  $r, '<swtest><foo>', '-M with import parameter' 
    $r = runperl: 
        switches    => \(@:  '-mswtest' )
        prog        => '1'
        

    do
        local $TODO = ''  # this one works on VMS
        is:  $r, '', '-m' 
    
    $r = runperl: 
        switches    => \(@:  '-mswtest=foo,bar' )
        prog        => '1'
        
    is:  $r, '<swtest><foo><bar>', '-m with import parameters' 
    push: @tmpfiles, $filename

    is:  (runperl:  switches => \(@:  '-MTie::Hash' ), stderr => 1, prog => 1 )
         '', "-MFoo::Bar allowed" 

    like:  (runperl:  switches => \(@:  '-M:swtest' ), stderr => 1
                      prog => 'die "oops"' )
           qr/Invalid module name [\w:]+ with -M option\b/
           "-M:Foo not allowed" 

    like:  (runperl:  switches => \(@:  '-mA:B:C' ), stderr => 1
                      prog => 'die "oops"' )
           qr/Invalid module name [\w:]+ with -m option\b/
           "-mFoo:Bar not allowed" 

    like:  (runperl:  switches => \(@:  '-m-A:B:C' ), stderr => 1
                      prog => 'die "oops"' )
           qr/Invalid module name [\w:]+ with -m option\b/
           "-m-Foo:Bar not allowed" 

    like:  (runperl:  switches => \(@:  '-m-' ), stderr => 1
                      prog => 'die "oops"' )
           qr/Module name required with -m option\b/
           "-m- not allowed" 

    like:  (runperl:  switches => \(@:  '-M-=' ), stderr => 1
                      prog => 'die "oops"' )
           qr/Module name required with -M option\b/
           "-M- not allowed" 


# Tests for -V

do
    local $TODO = ''   # these ones should work on VMS

    # basic perl -V should generate significant output.
    # we don't test actual format too much since it could change
    like:  (runperl:  switches => \(@: '-V') ), qr/(\n.*){20}/
           '-V generates 20+ lines' 

    like:  (runperl:  switches => \(@: '-V') )
           qr/\ASummary of my kurila .*configuration:/
           '-V looks okay' 

    # lookup a known config var
    chomp: ( $r=(runperl:  switches => \(@: '-V:osname') )) 
    is:  $r, "osname='$^OS_NAME';", 'perl -V:osname'

    # regexp lookup
    # platforms that don't like this quoting can either skip this test
    # or fix test.pl _quote_args
    $r = runperl:  switches => \(@: '"-V:i\D+size"') 
    # should be unlike( $r, qr/^$|not found|UNKNOWN/ );
    like:  $r, qr/^(?!.*(not found|UNKNOWN))./, 'perl -V:re got a result' 

    # make sure each line we got matches the re
    ok:  !( (grep: { !m/^i\D+size=/ }, (split: qr/^/, $r)) ), '-V:re correct' 


# Tests for -v

do
    local $TODO = ''   # these ones should work on VMS

    my (@: _, $v) =  split: m/-/, $^PERL_VERSION
    my $archname = config_value: 'archname'
    like:  (runperl:  switches => \(@: '-v') )
           qr/This[ ]is[ ]kurila,[  ]v$v [ ] (?:DEVEL:\S+[ ])? built[ ]for[ ]
             \Q$archname\E .+
             Copyright .+
             Gerard[ ]Goossen.+Artistic[ ]License .+
             GNU[ ]General[ ]Public[ ]License/xs
           '-v looks okay' 


# Tests for -h

do
    local $TODO = ''   # these ones should work on VMS

    like:  (runperl:  switches => \(@: '-h') )
           qr/Usage: .+(?i:perl(?:$((config_value: '_exe')))?).+switches.+programfile.+arguments/
           '-h looks okay' 


# Tests for switches which do not exist

foreach my $switch (split: m//, "ABbGgHJjKkLNOoPQqRrYyZz123456789_")
    local $TODO = ''   # these ones should work on VMS

    like:  (runperl:  switches => \(@: "-$switch"), stderr => 1
                      prog => 'die "oops"' )
           qr/\QUnrecognized switch: -$switch  (-h will show valid options)/
           "-$switch correctly unknown" 

