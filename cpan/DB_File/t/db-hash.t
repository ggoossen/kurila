#!./perl

use warnings

use Config

use DB_File
use Fcntl

use Test::More

plan: tests => 56

unlink: < glob: "__db.*"

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
    


sub docat_del
    my $file = shift
    local $^INPUT_RECORD_SEPARATOR = undef
    (open: my $catfh, "<",$file) || die: "Cannot open $file: $^OS_ERROR"
    my $result = ~< $catfh->*
    close: $catfh
    $result = normalise: $result 
    unlink: $file 
    return $result


sub normalise
    my $data = shift 
    $data =~ s#\r\n#\n#g
        if $^OS_NAME eq 'cygwin' 
    return $data 


my $Dfile = "dbhash.tmp"
my $Dfile2 = "dbhash2.tmp"
my $null_keys_allowed = ($DB_File::db_ver +< 2.004010
                         || $DB_File::db_ver +>= 3.1 )

unlink: $Dfile

umask: 0

# Check the interface to HASHINFO

my $dbh = DB_File::HASHINFO->new 

ok:  ! defined $dbh->{?bsize} 
ok:  ! defined $dbh->{?ffactor} 
ok:  ! defined $dbh->{?nelem} 
ok:  ! defined $dbh->{?cachesize} 
ok:  ! defined $dbh->{?hash} 
ok:  ! defined $dbh->{?lorder} 

$dbh->{+bsize} = 3000 
ok:  $dbh->{?bsize} == 3000 

$dbh->{+ffactor} = 9000 
ok:  $dbh->{?ffactor} == 9000 

$dbh->{+nelem} = 400 
ok:  $dbh->{?nelem} == 400 

$dbh->{+cachesize} = 65 
ok:  $dbh->{?cachesize} == 65 

my $some_sub = sub {} 
$dbh->{+hash} = $some_sub
ok:  $dbh->{hash} &== $some_sub 

$dbh->{+lorder} = 1234 
ok:  $dbh->{lorder} == 1234 


# Now check the interface to HASH
my %h = DB_File->new: $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_HASH 
ok:  %h

my (@: $dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime
       $blksize,$blocks) = @: stat: $Dfile

my %noMode = %:  < @+: map: { @: $_, 1 }, qw( amigaos MSWin32 NetWare cygwin )  

ok:  ($mode ^&^ 0777) == (($^OS_NAME eq 'os2' || $^OS_NAME eq 'MacOS') ?? 0666 !! 0640) ||
         %noMode{?$^OS_NAME} 

my ($key, $value, $i)
# while (@(?$key,?$value) = @: each(%h)) {
#     $i++;
# }
ok:  !$i 

%h->put: 'goner1', 'snork'

%h->put: 'abc', 'ABC'
is:  (%h->FETCH: "abc"), 'ABC' 
is:  (%h->FETCH: "jimmy"), undef 

%h->put: 'def', 'DEF'
%h->put: 'jkl' . "\034" . 'mno', "JKL\034MNO"
%h->put: (join: "\034", @: 'a',2,3,4,5), (join: "\034", @:'A',2,3,4,5)
%h->put: 'a', 'A'
%h->put: 'b', 'B'
%h->put: 'c', 'C'
%h->put: 'd', 'D' 
for (qw|e f g h i|)
    %h->put: $_, (uc: $_)


%h->put: 'goner2', 'snork'
%h->DELETE: 'goner2'

# IMPORTANT - $X must be undefined before the untie otherwise the
#             underlying DB close routine will not get called.
%h = undef


# tie to the same file again, do not supply a type - should default to HASH
%h = DB_File->new: $Dfile, O_RDWR, 0640
ok: %h

# Modify an entry from the previous tie
for (qw(g j k l m n o p q r s t u v w x y z))
    %h->put: $_, (uc: $_)


%h->del: 'goner1'

my @keys = %h->keys: 
my @values = %h->values: 

is:  (nelems: @keys), 30 
is:  (nelems: @values), 30 

$i = 0 
%h->iterate: 
    sub($key,$value)
        if ($key eq @keys[$i] && $value eq @values[$i] && $key eq (lc: $value))
            $key = uc: $key
            $i++ if $key eq $value
    

ok:  $i == 30 

@keys = @: 'blurfl', < %h->keys, 'dyick'
ok:  (nelems @keys) == 32 

%h->STORE: 'foo' => ''
ok:  (%h->FETCH: 'foo') eq '' 

# Berkeley DB from version 2.4.10 to 3.0 does not allow null keys.
# This feature was reenabled in version 3.1 of Berkeley DB.
my $result = 0 
if ($null_keys_allowed)
    %h->STORE: '' => 'bar'
    $result = ( (%h->FETCH: '') eq 'bar' )

else
   $result = 1
ok:  $result 

# check cache overflow and numeric keys and contents
my $ok = 1
for my $i (1..199) { %h->put:  $i + 0 => $i + 0 ; }
for my $i (1..199) { $ok = 0 unless (%h->FETCH: $i) == $i; }
ok:  $ok 

(@: $dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime
    $blksize,$blocks) = @: stat: $Dfile
ok:  $size +> 0 

# Now check all the non-tie specific stuff

# Check NOOVERWRITE will make put fail when attempting to overwrite
# an existing record.

my $status = %h->put:  'x', 'newvalue', (R_NOOVERWRITE: )
ok:  $status == 1 

# check that the value of the key 'x' has not been changed by the
# previous test
ok:  (%h->FETCH: 'x') eq 'X' 

# standard put
$status = %h->put: 'key', 'value' 
ok:  $status == 0 

#check that previous put can be retrieved
$value = 0 
$status = %h->get: 'key', $value 
ok:  $status == 0 
ok:  $value eq 'value' 

# Attempting to delete an existing key should work

$status = %h->del: 'q' 
ok:  $status == 0 

# Make sure that the key deleted, cannot be retrieved
do
    no warnings 'uninitialized' 
    ok:  (%h->FETCH: 'q') eq undef 


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

# ditto, but use put to replace the key/value pair.

# use seq to walk backwards through a file - check that this reversed is

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

do
    # check ability to override the default hashing
    my $filename = "xyz" 
    my $hi = DB_File::HASHINFO->new 
    $::count = 0 
    $hi->{+hash} = sub (@< @_) { ++$::count ; length @_[0] } 
    my %h = DB_File->new:  $filename, O_RDWR^|^O_CREAT, 0640, $hi  
    %h->put: "abc", 123 
    my $value
    %h->get: "abc", $value
    ok:  $value == 123 
    unlink: $filename 
    %h = undef
    local $TODO = 1
    ok:  $::count +>0  


ok:  1

do
    # Bug ID 20001013.009
    #
    # test that $hash{KEY} = undef doesn't produce the warning
    #     Use of uninitialized value in null operation
    use warnings 

    use DB_File 

    unlink: $Dfile
    my $a = ""
    local $^WARN_HOOK = sub (@< @_) {$a = @_[0]} 

    my %h = (DB_File->new:  $Dfile ) or die: "Can't open file: $^OS_ERROR\n" 
    %h->put: "ABC" => undef
    ok:  $a eq "" 
    undef %h
    unlink: $Dfile


do
    # Passing undef for flags and/or mode when calling tie could cause
    #     Use of uninitialized value in subroutine entry


    my $warn_count = 0 
    #local $SIG{__WARN__} = sub { ++ $warn_count };
    my %hash1
    unlink: $Dfile

    %hash1 = DB_File->new:  $Dfile, undef 
    ok:  $warn_count == 0
    $warn_count = 0
    undef %hash1
    unlink: $Dfile
    %hash1 = DB_File->new:  $Dfile, O_RDWR^|^O_CREAT, undef 
    ok:  $warn_count == 0
    undef %hash1
    unlink: $Dfile
    %hash1 = DB_File->new:  $Dfile, undef, undef 
    ok:  $warn_count == 0
    $warn_count = 0

    undef %hash1
    unlink: $Dfile



do
    # Regression Test for bug 30237
    # Check that substr can be used in the key to db_put
    # and that db_put does not trigger the warning
    #
    #     Use of uninitialized value in subroutine entry


    use warnings 

    my (%h) 
    my $Dfile = "xxy.db"
    unlink: $Dfile

    ok: ( %h = (DB_File->new:  $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_HASH )) 

    my $warned = ''
    local $^WARN_HOOK = sub (@< @_) {$warned = @_[0]} 

    # db-put with substr of key
    my %remember = $% 
    for my $ix ( 1 .. 2 )
        my $key = $ix . "data" 
        my $value = "value$ix" 
        %remember{+$key} = $value 
        %h->put: $key, $value 
    

    ok: $warned eq ''
        or print: $^STDOUT, "# Caught warning [$warned]\n" 

    # db-put with substr of value
    $warned = ''
    for my $ix ( 10 .. 12 )
        my $key = $ix . "data" 
        my $value = "value$ix" 
        %remember{+$key} = $value 
        %h->put: $key, $value 
    

    ok: $warned eq ''
        or print: $^STDOUT, "# Caught warning [$warned]\n" 

    # via the tied hash is not a problem, but check anyway
    # substr of key
    $warned = ''
    for my $ix ( 30 .. 32 )
        my $key = $ix . "data" 
        my $value = "value$ix" 
        %remember{+$key} = $value 
        %h->put: (substr: $key,0) => $value
    

    ok: $warned eq ''
        or print: $^STDOUT, "# Caught warning [$warned]\n" 

    # via the tied hash is not a problem, but check anyway
    # substr of value
    $warned = ''
    for my $ix ( 40 .. 42 )
        my $key = $ix . "data" 
        my $value = "value$ix" 
        %remember{+$key} = $value 
        %h->put: $key => (substr: $value,0) 
    

    ok: $warned eq ''
        or print: $^STDOUT, "# Caught warning [$warned]\n" 

    my %bad = $% 
    $key = ''
    my $status = %h->seq: $key, $value, R_FIRST 
    while ( $status == 0 )

        #print "# key [$key] value [$value]\n" ;
        if (defined %remember{?$key} && defined $value &&
            %remember{?$key} eq $value)
            delete %remember{$key} 
        else
            %bad{+$key} = $value 
        

        $status = %h->seq: $key, $value, R_NEXT 
    

    ok: nkeys %bad == 0 
    ok: nkeys %remember == 0 

    (print: $^STDOUT, "# missing -- $key=>$value\n") while (@: ?$key, ?$value) =@:  each %remember
    (print: $^STDOUT, "# bad     -- $key=>$value\n") while (@: ?$key, ?$value) =@:  each %bad

    # Make sure this fix does not break code to handle an undef key
    # Berkeley DB undef key is broken between versions 2.3.16 and 3.1
    my $value = 'fred'
    $warned = ''
    %h->put: undef, $value 
    ok: $warned eq ''
        or print: $^STDOUT, "# Caught warning [$warned]\n" 
    $warned = ''

    my $no_NULL = ($DB_File::db_ver +>= 2.003016 && $DB_File::db_ver +< 3.001) 
    print: $^STDOUT, "# db_ver $DB_File::db_ver\n"
    $value = '' 
    %h->get: undef, $value 
    ok: $no_NULL || $value eq 'fred' or print: $^STDOUT, "# got [$value]\n" 
    ok: $warned eq ''
        or print: $^STDOUT, "# Caught warning [$warned]\n" 
    $warned = ''

    undef %h
    unlink: $Dfile

