#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib/'
    else
        unshift: $^INCLUDE_PATH, 't/lib/'
    

chdir 't'

use File::Spec

use Test::More tests => 3

# Having the CWD in $^INCLUDE_PATH masked a bug in finding hint files
my $curdir = File::Spec->curdir: 
$^INCLUDE_PATH = grep: { $_ ne $curdir && $_ ne '.' }, $^INCLUDE_PATH

mkdir: 'hints', 0777
(my $os = $^OS_NAME) =~ s/\./_/g
my $hint_file = File::Spec->catfile: 'hints', "$os.pl"

(open: my $hintfh, ">", "$hint_file") || die: "Can't write dummy hints file $hint_file: $^OS_ERROR"
print: $hintfh, <<'CLOO'
our $self;
$self->{+CCFLAGS} = 'basset hounds got long ears';
CLOO
close $hintfh

use ExtUtils::MakeMaker

my $out
close $^STDERR
open: $^STDERR, '>>', \$out or die: 
my $mm = bless: \$%, 'ExtUtils::MakeMaker'
$mm->check_hints: 
is:  $mm->{+CCFLAGS}, 'basset hounds got long ears' 
is:  $out, "Processing hints file $hint_file\n" 

(open: $hintfh, ">", "$hint_file") || die: "Can't write dummy hints file $hint_file: $^OS_ERROR"
print: $hintfh, <<'CLOO'
die: "Argh!\n";
CLOO
close $hintfh

$out = ''
$mm->check_hints: 
like:  $out, qr/Processing hints file $hint_file\nArgh!/, 'hint files produce errors' 

END 
    use File::Path
    rmtree: 'hints'

