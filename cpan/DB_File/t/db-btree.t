#!./perl -w

use warnings

use Config

BEGIN

    if ($^OS_NAME eq 'darwin'
          && ( <(split: m/\./, (config_value: "osvers")))[[0]] +< 7 # Mac OS X 10.3 == Darwin 7
          && (config_value: "db_version_major") == 1
          && (config_value: "db_version_minor") == 0
          && (config_value: "db_version_patch") == 0)
        warn: <<EOM
#
# This test is known to crash in Mac OS X versions 10.2 (or earlier)
# because of the buggy Berkeley DB version included with the OS.
#
EOM
    


use Test::More

use DB_File
use Fcntl

plan: tests => 82

unlink: < glob: "__db.*"

sub lexical
    my @a = @:  unpack: "C*", $a  
    my @b = @:  unpack: "C*", $b  

    my $len = ((nelems @a) +> nelems @b ?? (nelems @b) !! nelems @a) 

    foreach my $i ( 0 .. $len -1)
        return @a[$i] - @b[$i] if @a[$i] != @b[$i] 
    

    return (nelems @a) - nelems @b 


do
    package Redirect 
    use Symbol 

    sub new
        my $class = shift 
        my $filename = shift 
        my $fh = (gensym: )
        (open: $fh, ">", "$filename") || die: "Cannot open $filename: $^OS_ERROR" 
        my $real_stdout = $^STDOUT
        return bless: \@: $fh, $real_stdout  

    
    sub DESTROY
        my $self = shift 
        close $self->[0] 
    


sub docat
    my $file = shift
    local $^INPUT_RECORD_SEPARATOR = undef 
    (open: my $catfh, "<",$file) || die: "Cannot open $file: $^OS_ERROR"
    my $result = ~< $catfh->*
    close: $catfh
    $result = normalise: $result 
    return $result 


sub docat_del
    my $file = shift
    my $result = docat: $file
    unlink: $file 
    return $result 


sub normalise
    my $data = shift 
    $data =~ s#\r\n#\n#g
        if $^OS_NAME eq 'cygwin' 

    return $data 


my $db185mode =  ($DB_File::db_version == 1 && ! $DB_File::db_185_compat) 
my $null_keys_allowed = ($DB_File::db_ver +< 2.004010
                         || $DB_File::db_ver +>= 3.1 )

my $Dfile = "dbbtree.tmp"
unlink: $Dfile

umask: 0

# Check the interface to BTREEINFO

my $dbh = DB_File::BTREEINFO->new 
ok:  ! defined $dbh->{?flags} 
ok:  ! defined $dbh->{?cachesize} 
ok:  ! defined $dbh->{?psize} 
ok:  ! defined $dbh->{?lorder} 
ok:  ! defined $dbh->{?minkeypage} 
ok:  ! defined $dbh->{?maxkeypage} 
ok:  ! defined $dbh->{?compare} 
ok:  ! defined $dbh->{?prefix} 

$dbh->{+flags} = 3000 
ok:  $dbh->{?flags} == 3000 

$dbh->{+cachesize} = 9000 
ok:  $dbh->{?cachesize} == 9000

$dbh->{+psize} = 400 
ok:  $dbh->{?psize} == 400 

$dbh->{+lorder} = 65 
ok:  $dbh->{?lorder} == 65 

$dbh->{+minkeypage} = 123 
ok:  $dbh->{?minkeypage} == 123 

$dbh->{+maxkeypage} = 1234 
ok:  $dbh->{?maxkeypage} == 1234 

# Now check the interface to BTREE

my (%h) 
do
    ok: ( %h = (DB_File->new:  $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_BTREE )) 

    my (@: $dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime
           $blksize,$blocks) = @: stat: $Dfile

    my %noMode = %:  < @+: map: { @: $_, 1 }, qw( amigaos MSWin32 NetWare cygwin )  

    ok:  ($mode ^&^ 0777) == (($^OS_NAME eq 'os2' || $^OS_NAME eq 'MacOS') ?? 0666 !! 0640)
             || %noMode{?$^OS_NAME} 

    my ($i)
    %h->iterate:  sub (@< @_) { $i++ } 
    ok:  !$i  

    %h->put: 'goner1' => 'snork'

    %h->put: 'abc' => 'ABC'
    ok:  (%h->FETCH: 'abc') eq 'ABC' 
    ok:  ! defined (%h->FETCH: 'jimmy')  
    ok:   defined (%h->FETCH: 'abc')  

    %h->put: 'def' => 'DEF'
    %h->put: 'jkl'.";".'mno' => "JKL;MNO"
    %h->put: (join: ";", (@:  'a',2,3,4,5)) => (join: ";", (@: 'A',2,3,4,5))
    %h->put: 'a' => 'A'

    #$h{'b' => 'B';
    %h->STORE: 'b', 'B'

    %h->put: 'c' => 'C'

    %h->put: 'd', 'D' 

    %h->put: 'e' => 'E'
    %h->put: 'f' => 'F'
    %h->put: 'g' => 'X'
    %h->put: 'h' => 'H'
    %h->put: 'i' => 'I'

    %h->put: 'goner2' => 'snork'
    %h->del: 'goner2'

    %h = undef


# tie to the same file again
ok: ( %h = (DB_File->new: $Dfile, O_RDWR, 0640, $DB_BTREE)) 

# Modify an entry from the previous tie
%h->put: 'g' => 'G'

%h->put: 'j' => 'J'
%h->put: 'k' => 'K'
%h->put: 'l' => 'L'
%h->put: 'm' => 'M'
%h->put: 'n' => 'N'
%h->put: 'o' => 'O'
%h->put: 'p' => 'P'
%h->put: 'q' => 'Q'
%h->put: 'r' => 'R'
%h->put: 's' => 'S'
%h->put: 't' => 'T'
%h->put: 'u' => 'U'
%h->put: 'v' => 'V'
%h->put: 'w' => 'W'
%h->put: 'x' => 'X'
%h->put: 'y' => 'Y'
%h->put: 'z' => 'Z'

%h->put: 'goner3' => 'snork'

%h->del: 'goner1'
%h->DELETE: 'goner3'

my @keys = %h->keys
my @values = %h->values

ok:  ((nelems @keys)-1) == 29 && ((nelems @values)-1) == 29 

my $i = 0 
%h->iterate: 
    sub($key, $value)
        if ($key eq @keys[$i] && $value eq @values[$i] && $key eq (lc: $value))
            $key = uc: $key
            $i++ if $key eq $value
    

ok:  $i == 30 

@keys = @: 'blurfl', < %h->keys, 'dyick'
ok:  ((nelems @keys)-1) == 31 

#Check that the keys can be retrieved in order
my @b = %h->keys 
my @c = sort: \&lexical, @b 
is_deeply: \@b, \@c

%h->put: 'foo' => ''
ok:  (%h->FETCH: 'foo') eq ''  

# Berkeley DB from version 2.4.10 to 3.0 does not allow null keys.
# This feature was reenabled in version 3.1 of Berkeley DB.
my $result = 0 
if ($null_keys_allowed)
    %h->put: '' => 'bar'
    $result = ( (%h->FETCH: '') eq 'bar' )

else
    $result = 1
ok:  $result 

# check cache overflow and numeric keys and contents
my $ok = 1
for my $i (1..199) { %h->put:  $i + 0 => $i + 0 ; }
for my $i (1..199) { $ok = 0 unless (%h->FETCH: $i) == $i; }
ok:  $ok

my (@: $dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime
       $blksize,$blocks) = @: stat: $Dfile
ok:  $size +> 0 

# Now check all the non-tie specific stuff


# Check R_NOOVERWRITE flag will make put fail when attempting to overwrite
# an existing record.

my $status = %h->put:  'x', 'newvalue', R_NOOVERWRITE 
ok:  $status == 1 

# check that the value of the key 'x' has not been changed by the
# previous test
ok:  (%h->FETCH: 'x') eq 'X' 

# standard put
$status = %h->put: 'key', 'value' 
ok:  $status == 0 

#check that previous put can be retrieved
my $value = 0 
$status = %h->get: 'key', $value 
ok:  $status == 0 
ok:  $value eq 'value' 

# Attempting to delete an existing key should work

$status = %h->del: 'q' 
ok:  $status == 0 
if ($null_keys_allowed)
    $status = %h->del: '' 
else
    $status = 0 

ok:  $status == 0 

# Make sure that the key deleted, cannot be retrieved
ok:  ! defined (%h->FETCH: 'q')
ok:  ! defined (%h->FETCH: '')

do
    undef %h

    ok: ( %h = (DB_File->new:  $Dfile, O_RDWR, 0640, $DB_BTREE ))


# Attempting to delete a non-existant key should fail

$status = %h->del: 'joe' 
ok:  $status == 1 

# Check the get interface

# First a non-existing key
$status = %h->get: 'aaaa', $value 
ok:  $status == 1 

# Next an existing key
$status = %h->get: 'a', $value 
ok:  $status == 0 
ok:  $value eq 'A' 

# seq
# ###

# use seq to find an approximate match
my $key = 'ke' 
$value = '' 
$status = %h->seq: $key, $value, R_CURSOR 
ok:  $status == 0 
ok:  $key eq 'key' 
ok:  $value eq 'value' 

# seq when the key does not match
$key = 'zzz' 
$value = '' 
$status = %h->seq: $key, $value, R_CURSOR 
ok:  $status == 1 


# use seq to set the cursor, then delete the record @ the cursor.

$key = 'x' 
$value = '' 
$status = %h->seq: $key, $value, R_CURSOR 
ok:  $status == 0 
ok:  $key eq 'x' 
ok:  $value eq 'X' 
$status = %h->del: 0, R_CURSOR 
ok:  $status == 0 
$status = %h->get: 'x', $value 
ok:  $status == 1 

# ditto, but use put to replace the key/value pair.
$key = 'y' 
$value = '' 
$status = %h->seq: $key, $value, R_CURSOR 
ok:  $status == 0 
ok:  $key eq 'y' 
ok:  $value eq 'Y' 

$key = "replace key" 
$value = "replace value" 
$status = %h->put: $key, $value, R_CURSOR 
ok:  $status == 0 
ok:  $key eq 'replace key' 
ok:  $value eq 'replace value' 
$status = %h->get: 'y', $value 
ok:  1  # hard-wire to always pass. the previous test ($status == 1)
# only worked because of a bug in 1.85/6

# use seq to walk forwards through a file

$status = %h->seq: $key, $value, R_FIRST 
ok:  $status == 0 
my $previous = $key 

$ok = 1 
while (($status = (%h->seq: $key, $value, R_NEXT)) == 0)
    ($ok = 0), last if ($previous cmp $key) == 1 


ok:  $status == 1 
ok:  $ok == 1 

# use seq to walk backwards through a file
$status = %h->seq: $key, $value, R_LAST 
ok:  $status == 0 
$previous = $key 

$ok = 1 
while (($status = (%h->seq: $key, $value, R_PREV)) == 0)
    ($ok = 0), last if ($previous cmp $key) == -1 
#print "key = [$key] value = [$value]\n" ;


ok:  $status == 1 
ok:  $ok == 1 


# check seq FIRST/LAST

# sync
# ####

$status = %h->sync 
ok:  $status == 0 


# fd
# ##

$status = %h->fd 
ok:  1 
#ok( $status != 0 );


undef %h 

unlink: $Dfile

# Now try an in memory file
ok: ( %h = (DB_File->new:  undef, O_RDWR^|^O_CREAT, 0640, $DB_BTREE ))

# fd with an in memory file should return failure
$status = %h->fd 
ok:  $status == -1 


undef %h 

# Duplicate keys
my $bt = DB_File::BTREEINFO->new 
$bt->{GOT}->{+flags} = R_DUP 
ok: ( my %hh = (DB_File->new:  $Dfile, O_RDWR^|^O_CREAT, 0640, $bt )) 

%hh->STORE: 'Wall' => 'Larry' 
%hh->STORE: 'Wall' => 'Stone'  # Note the duplicate key
%hh->STORE: 'Wall' => 'Brick'  # Note the duplicate key
%hh->STORE: 'Wall' => 'Brick'  # Note the duplicate key and value
%hh->STORE: 'Smith' => 'John' 
%hh->STORE: 'mouse' => 'mickey' 

# first work in scalar context
ok:  (nelems:  (%hh->get_dup: 'Unknown') ) == 0 
ok:  (nelems:  (%hh->get_dup: 'Smith') ) == 1 
ok:  (nelems:  (%hh->get_dup: 'Wall') ) == 4 

# now in list context
my @unknown = %hh->get_dup: 'Unknown' 
ok:  "$((join: ' ',@unknown))" eq "" 

my @smith = %hh->get_dup: 'Smith' 
ok:  "$((join: ' ',@smith))" eq "John" 

do
    my @wall = %hh->get_dup: 'Wall' 
    my %wall 
    %wall{[ @wall]} =  @wall 
    ok:  ((nelems @wall) == 4 && %wall{?'Larry'} && %wall{?'Stone'} && %wall{?'Brick'}) 


# hash
my %unknown = %:  < %hh->get_dup: 'Unknown', 1  
ok:  ! %unknown 

my %smith = %:  < %hh->get_dup: 'Smith', 1  
ok:  nkeys %smith == 1 && %smith{?'John'} 

my %wall = %:  < %hh->get_dup: 'Wall', 1  
ok:  nkeys %wall == 3 && %wall{?'Larry'} == 1 && %wall{?'Stone'} == 1
         && %wall{?'Brick'} == 2

undef %hh 
unlink: $Dfile

# clear
# #####

my $Dfile1 = "btree1"

ok: ( %h = (DB_File->new:  $Dfile1, O_RDWR^|^O_CREAT, 0640, $DB_BTREE )) 
foreach (1 .. 10)
    %h->put:  $_ => $_ * 100 

# check that there are 10 elements in the hash
$i = 0 
%h->iterate: 
    sub($key, $value)
        $i++
    
ok:  $i == 10

# now clear the hash
%h = $% 

# check it is empty
$i = 0 
while ((@: ?$key,?$value) = @: (each: %h))
    $i++

ok:  $i == 0

undef %h 
unlink: $Dfile1 

