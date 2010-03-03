#!./perl -w

#
# test auto defined() test insertion
#

our $warns

BEGIN 
    $^WARN_HOOK = sub (@< @_) { $warns++; print: $^STDERR, @_[0]->message }

require './test.pl'
plan:  tests => 16 

my $wanted_filename = $^OS_NAME eq 'VMS' ?? '0.' !! '0'
my $saved_filename = $^OS_NAME eq 'MacOS' ?? ':0' !! './0'

cmp_ok: $warns,'==',0,'no warns at start'

open: my $file, ">","$saved_filename"
ok: (defined: 'FILE'),'created work file'
print: $file, "1\n"
print: $file, "0"
close: $file

open: $file, "<","$saved_filename"
ok: (defined: 'FILE'),'opened work file'
my $seen = 0
my $dummy
while (my $name = ~< $file)
    $seen++ if $name eq '0'

cmp_ok: $seen,'==',1,'seen in while()'

seek: $file,0,0
$seen = 0
my $line = ''
do
    $seen++ if $line eq '0'
 while ($line = ~< $file)
cmp_ok: $seen,'==',1,'seen in do/while'

seek: $file,0,0
$seen = 0
my $name
while (($seen ?? $dummy !! $name) = ~< $file )
    $seen++ if $name eq '0'

cmp_ok: $seen,'==',1,'seen in while() ternary'

seek: $file,0,0
$seen = 0
my %where
while (%where{+$seen} = ~< $file)
    $seen++ if %where{?$seen} eq '0'

cmp_ok: $seen,'==',1,'seen in hash while()'
close $file

opendir: my $dir,($^OS_NAME eq 'MacOS' ?? ':' !! '.')
ok: (defined: 'DIR'),'opened current directory'
$seen = 0
while (my $name = (readdir: $dir))
    $seen++ if $name eq $wanted_filename

cmp_ok: $seen,'==',1,'saw work file once'

rewinddir: $dir
$seen = 0
$dummy = ''
while (($seen ?? $dummy !! $name) = (readdir: $dir))
    $seen++ if $name eq $wanted_filename

cmp_ok: $seen,'+>',0,'saw file in while() ternary'

rewinddir: $dir
$seen = 0
while (%where{+$seen} = (readdir: $dir))
    $seen++ if %where{?$seen} eq $wanted_filename

cmp_ok: $seen,'==',1,'saw file in hash while()'

unlink: $saved_filename
ok: !(-f $saved_filename),'work file unlinked'

my %hash = %: 0 => 1, 1 => 2

$seen = 0
while (my $name = each %hash)
    $seen++ if $name eq '0'

cmp_ok: $seen,'==',1,'seen in each'

$seen = 0
$dummy = ''
while (($seen ?? $dummy !! my $name) = each %hash)
    $seen++ if $name eq '0'

cmp_ok: $seen,'==',1,'seen in each ternary'

$seen = 0
while (%where{+$seen} = each %hash)
    $seen++ if %where{?$seen} eq '0'

cmp_ok: $seen,'==',1,'seen in each hash'

cmp_ok: $warns,'==',0,'no warns at finish'
