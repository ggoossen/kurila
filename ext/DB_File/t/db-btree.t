#!./perl -w

use warnings;
use strict;
use Config;
 
BEGIN {
    if(-d "lib" && -f "TEST") {
        if (%Config{'extensions'} !~ m/\bDB_File\b/ ) {
            print "1..0 # Skip: DB_File was not built\n";
            exit 0;
        }
    }
}

BEGIN
{
    if ($^O eq 'darwin'
	&& (split(m/\./, %Config{osvers}))[[0]] +< 7 # Mac OS X 10.3 == Darwin 7
	&& %Config{db_version_major} == 1
	&& %Config{db_version_minor} == 0
	&& %Config{db_version_patch} == 0) {
	warn <<EOM;
#
# This test is known to crash in Mac OS X versions 10.2 (or earlier)
# because of the buggy Berkeley DB version included with the OS.
#
EOM
    }
}

use Test::More;

use DB_File; 
use Fcntl;

plan tests => 196;

unlink < glob "__db.*";

sub lexical
{
    my(@a) = @( unpack ("C*", $a) ) ;
    my(@b) = @( unpack ("C*", $b) ) ;

    my $len = ((nelems @a) +> nelems @b ? (nelems @b) : nelems @a) ;
    my $i = 0 ;

    foreach $i ( 0 .. $len -1) {
        return @a[$i] - @b[$i] if @a[$i] != @b[$i] ;
    }

    return (nelems @a) - nelems @b ;
}

{
    package Redirect ;
    use Symbol ;

    sub new
    {
        my $class = shift ;
        my $filename = shift ;
	my $fh = gensym ;
	open ($fh, ">", "$filename") || die "Cannot open $filename: $!" ;
	my $real_stdout = select($fh) ;
	return bless \@($fh, $real_stdout ) ;

    }
    sub DESTROY
    {
        my $self = shift ;
	close $self->[0] ;
	select($self->[1]) ;
    }
}

sub docat
{ 
    my $file = shift;
    local $/ = undef ;
    open(CAT, "<",$file) || die "Cannot open $file: $!";
    my $result = ~< *CAT;
    close(CAT);
    $result = normalise($result) ;
    return $result ;
}   

sub docat_del
{ 
    my $file = shift;
    my $result = docat($file);
    unlink $file ;
    return $result ;
}   

sub normalise
{
    my $data = shift ;
    $data =~ s#\r\n#\n#g 
        if $^O eq 'cygwin' ;

    return $data ;
}

sub safeUntie
{
    my $hashref = shift ;
    my $no_inner = 1;
    local $^WARN_HOOK = sub {-- $no_inner } ;
    untie %$hashref;
    return $no_inner;
}



my $db185mode =  ($DB_File::db_version == 1 && ! $DB_File::db_185_compat) ;
my $null_keys_allowed = ($DB_File::db_ver +< 2.004010 
				|| $DB_File::db_ver +>= 3.1 );

my $Dfile = "dbbtree.tmp";
unlink $Dfile;

umask(0);

# Check the interface to BTREEINFO

my $dbh = DB_File::BTREEINFO->new() ;
ok( ! defined $dbh->{flags}) ;
ok( ! defined $dbh->{cachesize}) ;
ok( ! defined $dbh->{psize}) ;
ok( ! defined $dbh->{lorder}) ;
ok( ! defined $dbh->{minkeypage}) ;
ok( ! defined $dbh->{maxkeypage}) ;
ok( ! defined $dbh->{compare}) ;
ok( ! defined $dbh->{prefix}) ;

$dbh->{flags} = 3000 ;
ok( $dbh->{flags} == 3000) ;

$dbh->{cachesize} = 9000 ;
ok( $dbh->{cachesize} == 9000);

$dbh->{psize} = 400 ;
ok( $dbh->{psize} == 400) ;

$dbh->{lorder} = 65 ;
ok( $dbh->{lorder} == 65) ;

$dbh->{minkeypage} = 123 ;
ok( $dbh->{minkeypage} == 123) ;

$dbh->{maxkeypage} = 1234 ;
ok( $dbh->{maxkeypage} == 1234 );

# Check that an invalid entry is caught both for store & fetch
eval '$dbh->{fred} = 1234' ;
ok( $@->{description} =~ m/^DB_File::BTREEINFO::STORE - Unknown element 'fred' at/ ) ;
eval 'my $q = $dbh->{fred}' ;
ok( $@->{description} =~ m/^DB_File::BTREEINFO::FETCH - Unknown element 'fred' at/ ) ;

# Now check the interface to BTREE

my ($X, %h) ;
ok( $X = tie(%h, 'DB_File',$Dfile, O_RDWR^|^O_CREAT, 0640, $DB_BTREE )) ;
die "Could not tie: $!" unless $X;

my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
   $blksize,$blocks) = stat($Dfile);

my %noMode = %( map { $_, 1} qw( amigaos MSWin32 NetWare cygwin ) ) ;

ok( ($mode ^&^ 0777) == (($^O eq 'os2' || $^O eq 'MacOS') ? 0666 : 0640)
   || %noMode{$^O} );

my ($key, $value, $i);
while (($key,$value) = each(%h)) {
    $i++;
}
ok( !$i ) ;

%h{'goner1'} = 'snork';

%h{'abc'} = 'ABC';
ok( %h{'abc'} eq 'ABC' );
ok( ! defined %h{'jimmy'} ) ;
ok( ! exists %h{'jimmy'} ) ;
ok(  defined %h{'abc'} ) ;

%h{'def'} = 'DEF';
%h{'jkl','mno'} = "JKL\034MNO";
%h{'a',2,3,4,5} = join("\034",'A',2,3,4,5);
%h{'a'} = 'A';

#$h{'b'} = 'B';
$X->STORE('b', 'B') ;

%h{'c'} = 'C';

#$h{'d'} = 'D';
$X->put('d', 'D') ;

%h{'e'} = 'E';
%h{'f'} = 'F';
%h{'g'} = 'X';
%h{'h'} = 'H';
%h{'i'} = 'I';

%h{'goner2'} = 'snork';
delete %h{'goner2'};


# IMPORTANT - $X must be undefined before the untie otherwise the
#             underlying DB close routine will not get called.
undef $X ;
untie(%h);

# tie to the same file again
ok( $X = tie(%h,'DB_File',$Dfile, O_RDWR, 0640, $DB_BTREE)) ;

# Modify an entry from the previous tie
%h{'g'} = 'G';

%h{'j'} = 'J';
%h{'k'} = 'K';
%h{'l'} = 'L';
%h{'m'} = 'M';
%h{'n'} = 'N';
%h{'o'} = 'O';
%h{'p'} = 'P';
%h{'q'} = 'Q';
%h{'r'} = 'R';
%h{'s'} = 'S';
%h{'t'} = 'T';
%h{'u'} = 'U';
%h{'v'} = 'V';
%h{'w'} = 'W';
%h{'x'} = 'X';
%h{'y'} = 'Y';
%h{'z'} = 'Z';

%h{'goner3'} = 'snork';

delete %h{'goner1'};
$X->DELETE('goner3');

my @keys = @( keys(%h) );
my @values = @( values(%h) );

ok( ((nelems @keys)-1) == 29 && ((nelems @values)-1) == 29) ;

$i = 0 ;
while (($key,$value) = each(%h)) {
    if ($key eq @keys[$i] && $value eq @values[$i] && $key eq lc($value)) {
	$key = uc($key);
	$i++ if $key eq $value;
    }
}

ok( $i == 30) ;

@keys = @('blurfl', keys(%h), 'dyick');
ok( ((nelems @keys)-1) == 31) ;

#Check that the keys can be retrieved in order
my @b = @( keys %h ) ;
my @c = @( sort lexical < @b ) ;
is_deeply(\@b, \@c);

%h{'foo'} = '';
ok( %h{'foo'} eq '' ) ;

# Berkeley DB from version 2.4.10 to 3.0 does not allow null keys.
# This feature was reenabled in version 3.1 of Berkeley DB.
my $result = 0 ;
if ($null_keys_allowed) {
    %h{''} = 'bar';
    $result = ( %h{''} eq 'bar' );
}
else
  { $result = 1 }
ok( $result) ;

# check cache overflow and numeric keys and contents
my $ok = 1;
for ($i = 1; $i +< 200; $i++) { %h{$i + 0} = $i + 0; }
for ($i = 1; $i +< 200; $i++) { $ok = 0 unless %h{$i} == $i; }
ok( $ok);

($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
   $blksize,$blocks) = stat($Dfile);
ok( $size +> 0 );

%h{[0..200]} = 200..400;
my @foo = @( %h{[0..200]} );
ok( join(':',200..400) eq join(':',< @foo) );

# Now check all the non-tie specific stuff


# Check R_NOOVERWRITE flag will make put fail when attempting to overwrite
# an existing record.
 
my $status = $X->put( 'x', 'newvalue', R_NOOVERWRITE) ;
ok( $status == 1 );
 
# check that the value of the key 'x' has not been changed by the 
# previous test
ok( %h{'x'} eq 'X' );

# standard put
$status = $X->put('key', 'value') ;
ok( $status == 0 );

#check that previous put can be retrieved
$value = 0 ;
$status = $X->get('key', $value) ;
ok( $status == 0 );
ok( $value eq 'value' );

# Attempting to delete an existing key should work

$status = $X->del('q') ;
ok( $status == 0 );
if ($null_keys_allowed) {
    $status = $X->del('') ;
} else {
    $status = 0 ;
}
ok( $status == 0 );

# Make sure that the key deleted, cannot be retrieved
ok( ! defined %h{'q'}) ;
ok( ! defined %h{''}) ;

undef $X ;
untie %h ;

ok( $X = tie(%h, 'DB_File',$Dfile, O_RDWR, 0640, $DB_BTREE ));

# Attempting to delete a non-existant key should fail

$status = $X->del('joe') ;
ok( $status == 1 );

# Check the get interface

# First a non-existing key
$status = $X->get('aaaa', $value) ;
ok( $status == 1 );

# Next an existing key
$status = $X->get('a', $value) ;
ok( $status == 0 );
ok( $value eq 'A' );

# seq
# ###

# use seq to find an approximate match
$key = 'ke' ;
$value = '' ;
$status = $X->seq($key, $value, R_CURSOR) ;
ok( $status == 0 );
ok( $key eq 'key' );
ok( $value eq 'value' );

# seq when the key does not match
$key = 'zzz' ;
$value = '' ;
$status = $X->seq($key, $value, R_CURSOR) ;
ok( $status == 1 );


# use seq to set the cursor, then delete the record @ the cursor.

$key = 'x' ;
$value = '' ;
$status = $X->seq($key, $value, R_CURSOR) ;
ok( $status == 0 );
ok( $key eq 'x' );
ok( $value eq 'X' );
$status = $X->del(0, R_CURSOR) ;
ok( $status == 0 );
$status = $X->get('x', $value) ;
ok( $status == 1 );

# ditto, but use put to replace the key/value pair.
$key = 'y' ;
$value = '' ;
$status = $X->seq($key, $value, R_CURSOR) ;
ok( $status == 0 );
ok( $key eq 'y' );
ok( $value eq 'Y' );

$key = "replace key" ;
$value = "replace value" ;
$status = $X->put($key, $value, R_CURSOR) ;
ok( $status == 0 );
ok( $key eq 'replace key' );
ok( $value eq 'replace value' );
$status = $X->get('y', $value) ;
ok( 1) ; # hard-wire to always pass. the previous test ($status == 1)
	    # only worked because of a bug in 1.85/6

# use seq to walk forwards through a file 

$status = $X->seq($key, $value, R_FIRST) ;
ok( $status == 0 );
my $previous = $key ;

$ok = 1 ;
while (($status = $X->seq($key, $value, R_NEXT)) == 0)
{
    ($ok = 0), last if ($previous cmp $key) == 1 ;
}

ok( $status == 1 );
ok( $ok == 1 );

# use seq to walk backwards through a file 
$status = $X->seq($key, $value, R_LAST) ;
ok( $status == 0 );
$previous = $key ;

$ok = 1 ;
while (($status = $X->seq($key, $value, R_PREV)) == 0)
{
    ($ok = 0), last if ($previous cmp $key) == -1 ;
    #print "key = [$key] value = [$value]\n" ;
}

ok( $status == 1 );
ok( $ok == 1 );


# check seq FIRST/LAST

# sync
# ####

$status = $X->sync ;
ok( $status == 0 );


# fd
# ##

$status = $X->fd ;
ok( 1 );
#ok( $status != 0 );


undef $X ;
untie %h ;

unlink $Dfile;

# Now try an in memory file
my $Y;
ok( $Y = tie(%h, 'DB_File',undef, O_RDWR^|^O_CREAT, 0640, $DB_BTREE ));

# fd with an in memory file should return failure
$status = $Y->fd ;
ok( $status == -1 );


undef $Y ;
untie %h ;

# Duplicate keys
my $bt = DB_File::BTREEINFO->new() ;
$bt->{flags} = R_DUP ;
my ($YY, %hh);
ok( $YY = tie(%hh, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $bt )) ;

%hh{'Wall'} = 'Larry' ;
%hh{'Wall'} = 'Stone' ; # Note the duplicate key
%hh{'Wall'} = 'Brick' ; # Note the duplicate key
%hh{'Wall'} = 'Brick' ; # Note the duplicate key and value
%hh{'Smith'} = 'John' ;
%hh{'mouse'} = 'mickey' ;

# first work in scalar context
ok( nelems( $YY->get_dup('Unknown') ) == 0 );
ok( nelems( $YY->get_dup('Smith') ) == 1 );
ok( nelems( $YY->get_dup('Wall') ) == 4 );

# now in list context
my @unknown = @( < $YY->get_dup('Unknown') ) ;
ok( "{join ' ', <@unknown}" eq "" );

my @smith = @( < $YY->get_dup('Smith') ) ;
ok( "{join ' ', <@smith}" eq "John" );

{
my @wall = @( < $YY->get_dup('Wall') ) ;
my %wall ;
%wall{[< @wall]} = < @wall ;
ok( ((nelems @wall) == 4 && %wall{'Larry'} && %wall{'Stone'} && %wall{'Brick'}) );
}

# hash
my %unknown = %( < $YY->get_dup('Unknown', 1) ) ;
ok( ! %unknown );

my %smith = %( < $YY->get_dup('Smith', 1) ) ;
ok( nkeys %smith == 1 && %smith{'John'}) ;

my %wall = %( < $YY->get_dup('Wall', 1) ) ;
ok( nkeys %wall == 3 && %wall{'Larry'} == 1 && %wall{'Stone'} == 1 
		&& %wall{'Brick'} == 2);

undef $YY ;
untie %hh ;
unlink $Dfile;


# test multiple callbacks
my $Dfile1 = "btree1" ;
my $Dfile2 = "btree2" ;
my $Dfile3 = "btree3" ;
 
my $dbh1 = DB_File::BTREEINFO->new() ;
$dbh1->{compare} = sub { 
	no warnings 'numeric' ;
	@_[0] <+> @_[1] } ; 
 
my $dbh2 = DB_File::BTREEINFO->new() ;
$dbh2->{compare} = sub { @_[0] cmp @_[1] } ;
 
my $dbh3 = DB_File::BTREEINFO->new() ;
$dbh3->{compare} = sub { length @_[0] <+> length @_[1] } ;
 
 
my (%g, %k);
tie(%h, 'DB_File',$Dfile1, O_RDWR^|^O_CREAT, 0640, $dbh1 ) or die $!;
tie(%g, 'DB_File',$Dfile2, O_RDWR^|^O_CREAT, 0640, $dbh2 ) or die $!;
tie(%k, 'DB_File',$Dfile3, O_RDWR^|^O_CREAT, 0640, $dbh3 ) or die $!;
 
my @Keys = @( qw( 0123 12 -1234 9 987654321 def  ) ) ;
my (@srt_1, @srt_2, @srt_3);
{ 
  no warnings 'numeric' ;
  @srt_1 = @( sort { $a <+> $b } < @Keys ) ; 
}
@srt_2 = @( sort { $a cmp $b } < @Keys ) ;
@srt_3 = @( sort { length $a <+> length $b } < @Keys ) ;
 
foreach (< @Keys) {
    %h{$_} = 1 ;
    %g{$_} = 1 ;
    %k{$_} = 1 ;
}
 
is_deeply(\@srt_1, \@(keys %h));
is_deeply(\@srt_2, \@(keys %g));
is_deeply(\@srt_3, \@(keys %k));

untie %h ;
untie %g ;
untie %k ;
unlink $Dfile1, $Dfile2, $Dfile3 ;

# clear
# #####

ok( tie(%h, 'DB_File', $Dfile1, O_RDWR^|^O_CREAT, 0640, $DB_BTREE ) );
foreach (1 .. 10)
  { %h{$_} = $_ * 100 }

# check that there are 10 elements in the hash
$i = 0 ;
while (($key,$value) = each(%h)) {
    $i++;
}
ok( $i == 10);

# now clear the hash
%h = %( () ) ;

# check it is empty
$i = 0 ;
while (($key,$value) = each(%h)) {
    $i++;
}
ok( $i == 0);

untie %h ;
unlink $Dfile1 ;

{
   # sub-class test

   package Another ;

   use warnings ;
   use strict ;

   open(FILE, ">", "SubDB.pm") or die "Cannot open SubDB.pm: $!\n" ;
   print FILE <<'EOM' ;

   package SubDB ;

   use warnings ;
   use strict ;
   our (@ISA, @EXPORT);

   require Exporter ;
   use DB_File;
   @ISA= @( qw(DB_File) );
   @EXPORT = @DB_File::EXPORT ;

   sub STORE { 
	my $self = shift ;
        my $key = shift ;
        my $value = shift ;
        $self->SUPER::STORE($key, $value * 2) ;
   }

   sub FETCH { 
	my $self = shift ;
        my $key = shift ;
        $self->SUPER::FETCH($key) - 1 ;
   }

   sub put { 
	my $self = shift ;
        my $key = shift ;
        my $value = shift ;
        $self->SUPER::put($key, $value * 3) ;
   }

   sub get { 
	my $self = shift ;
        $self->SUPER::get(@_[0], @_[1]) ;
	@_[1] -= 2 ;
   }

   sub A_new_method
   {
	my $self = shift ;
        my $key = shift ;
        my $value = $self->FETCH($key) ;
	return "[[$value]]" ;
   }

   1 ;
EOM

    close FILE ;

    BEGIN { push @INC, '.'; }    
    eval 'use SubDB ; ';
    die if $@;
    main::ok( $@ eq "") ;
    my %h ;
    my $X ;
    eval '
	$X = tie(%h, "SubDB","dbbtree.tmp", O_RDWR^|^O_CREAT, 0640, $DB_BTREE );
	' ;

    main::ok( $@ eq "") ;

    my $ret = eval '%h{"fred"} = 3 ; return %h{"fred"} ' ;
    main::ok( ! $@) ;
    main::ok( $ret == 5) ;

    my $value = 0;
    $ret = eval '$X->put("joe", 4) ; $X->get("joe", $value) ; return $value' ;
    main::ok( ! $@ ) ;
    main::ok( $ret == 10) ;

    $ret = eval ' R_NEXT eq main::R_NEXT ' ;
    main::ok( $@ eq "" ) ;
    main::ok( $ret == 1) ;

    $ret = eval '$X->A_new_method("joe") ' ;
    main::ok( $@ eq "") ;
    main::ok( $ret eq "[[11]]") ;

    undef $X;
    untie(%h);
    unlink "SubDB.pm", "dbbtree.tmp" ;

}

{
   # DBM Filter tests
   use warnings ;
   use strict ;
   my (%h, $db) ;
   my ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   unlink $Dfile;

   sub checkOutput
   {
       my($fk, $sk, $fv, $sv) = < @_ ;
       return
           $fetch_key eq $fk && $store_key eq $sk && 
	   $fetch_value eq $fv && $store_value eq $sv &&
	   $_ eq 'original' ;
   }
   
   ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_BTREE ) );

   $db->filter_fetch_key   (sub { $fetch_key = $_ }) ;
   $db->filter_store_key   (sub { $store_key = $_ }) ;
   $db->filter_fetch_value (sub { $fetch_value = $_}) ;
   $db->filter_store_value (sub { $store_value = $_ }) ;

   $_ = "original" ;

   %h{"fred"} = "joe" ;
   #                   fk   sk     fv   sv
   ok( checkOutput( "", "fred", "", "joe")) ;

   ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   ok( %h{"fred"} eq "joe");
   #                   fk    sk     fv    sv
   ok( checkOutput( "", "fred", "joe", "")) ;

   ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   ok( $db->FIRSTKEY() eq "fred") ;
   #                    fk     sk  fv  sv
   ok( checkOutput( "fred", "", "", "")) ;

   # replace the filters, but remember the previous set
   my $old_fk = $db->filter_fetch_key   
   			(sub { $_ = uc $_ ; $fetch_key = $_ }) ;
   my $old_sk = $db->filter_store_key   
   			(sub { $_ = lc $_ ; $store_key = $_ }) ;
   my $old_fv = $db->filter_fetch_value 
   			(sub { $_ = "[$_]"; $fetch_value = $_ }) ;
   my $old_sv = $db->filter_store_value 
   			(sub { s/o/x/g; $store_value = $_ }) ;
   
   ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   %h{"Fred"} = "Joe" ;
   #                   fk   sk     fv    sv
   ok( checkOutput( "", "fred", "", "Jxe")) ;

   ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   ok( %h{"Fred"} eq "[Jxe]");
   #                   fk   sk     fv    sv
   ok( checkOutput( "", "fred", "[Jxe]", "")) ;

   ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   ok( $db->FIRSTKEY() eq "FRED") ;
   #                   fk   sk     fv    sv
   ok( checkOutput( "FRED", "", "", "")) ;

   # put the original filters back
   $db->filter_fetch_key   ($old_fk);
   $db->filter_store_key   ($old_sk);
   $db->filter_fetch_value ($old_fv);
   $db->filter_store_value ($old_sv);

   ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   %h{"fred"} = "joe" ;
   ok( checkOutput( "", "fred", "", "joe")) ;

   ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   ok( %h{"fred"} eq "joe");
   ok( checkOutput( "", "fred", "joe", "")) ;

   ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   ok( $db->FIRSTKEY() eq "fred") ;
   ok( checkOutput( "fred", "", "", "")) ;

   # delete the filters
   $db->filter_fetch_key   (undef);
   $db->filter_store_key   (undef);
   $db->filter_fetch_value (undef);
   $db->filter_store_value (undef);

   ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   %h{"fred"} = "joe" ;
   ok( checkOutput( "", "", "", "")) ;

   ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   ok( %h{"fred"} eq "joe");
   ok( checkOutput( "", "", "", "")) ;

   ($fetch_key, $store_key, $fetch_value, $store_value) = ("") x 4 ;
   ok( $db->FIRSTKEY() eq "fred") ;
   ok( checkOutput( "", "", "", "")) ;

   undef $db ;
   untie %h;
   unlink $Dfile;
}

{    
    # DBM Filter with a closure

    use warnings ;
    use strict ;
    my (%h, $db) ;

    unlink $Dfile;
    ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_BTREE ) );

    my %result = %( () ) ;

    sub Closure
    {
        my ($name) = < @_ ;
	my $count = 0 ;
	my @kept = @( () ) ;

	return sub { ++$count ; 
		     push @kept, $_ ; 
		     %result{$name} = "$name - $count: [{join ' ', <@kept}]" ;
		   }
    }

    $db->filter_store_key(Closure("store key")) ;
    $db->filter_store_value(Closure("store value")) ;
    $db->filter_fetch_key(Closure("fetch key")) ;
    $db->filter_fetch_value(Closure("fetch value")) ;

    $_ = "original" ;

    %h{"fred"} = "joe" ;
    ok( %result{"store key"} eq "store key - 1: [fred]");
    ok( %result{"store value"} eq "store value - 1: [joe]");
    ok( ! defined %result{"fetch key"} );
    ok( ! defined %result{"fetch value"} );
    ok( $_ eq "original") ;

    ok( $db->FIRSTKEY() eq "fred") ;
    ok( %result{"store key"} eq "store key - 1: [fred]");
    ok( %result{"store value"} eq "store value - 1: [joe]");
    ok( %result{"fetch key"} eq "fetch key - 1: [fred]");
    ok( ! defined %result{"fetch value"} );
    ok( $_ eq "original") ;

    %h{"jim"}  = "john" ;
    ok( %result{"store key"} eq "store key - 2: [fred jim]");
    ok( %result{"store value"} eq "store value - 2: [joe john]");
    ok( %result{"fetch key"} eq "fetch key - 1: [fred]");
    ok( ! defined %result{"fetch value"} );
    ok( $_ eq "original") ;

    ok( %h{"fred"} eq "joe");
    ok( %result{"store key"} eq "store key - 3: [fred jim fred]");
    ok( %result{"store value"} eq "store value - 2: [joe john]");
    ok( %result{"fetch key"} eq "fetch key - 1: [fred]");
    ok( %result{"fetch value"} eq "fetch value - 1: [joe]");
    ok( $_ eq "original") ;

    undef $db ;
    untie %h;
    unlink $Dfile;
}		

{
   # DBM Filter recursion detection
   use warnings ;
   use strict ;
   my (%h, $db) ;
   unlink $Dfile;

   ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_BTREE ) );

   $db->filter_store_key (sub { $_ = %h{$_} }) ;

   eval '%h{1} = 1234' ;
   ok( $@->{description} =~ m/^recursion detected in filter_store_key/ );
   
   undef $db ;
   untie %h;
   unlink $Dfile;
}


{
   # Examples from the POD


  my $file = "xyzt" ;
  {
    my $redirect = Redirect->new( $file) ;

    # BTREE example 1
    ###

    use warnings FATAL => qw(all) ;
    use strict ;
    use DB_File ;

    my %h ;

    sub Compare
    {
        my ($key1, $key2) = < @_ ;
        (lc "$key1") cmp (lc "$key2") ;
    }

    # specify the Perl sub that will do the comparison
    $DB_BTREE->{'compare'} = \&Compare ;

    unlink "tree" ;
    tie %h, "DB_File", "tree", O_RDWR^|^O_CREAT, 0640, $DB_BTREE 
        or die "Cannot open file 'tree': $!\n" ;

    # Add a key/value pair to the file
    %h{'Wall'} = 'Larry' ;
    %h{'Smith'} = 'John' ;
    %h{'mouse'} = 'mickey' ;
    %h{'duck'}  = 'donald' ;

    # Delete
    delete %h{"duck"} ;

    # Cycle through the keys printing them in order.
    # Note it is not necessary to sort the keys as
    # the btree will have kept them in order automatically.
    foreach (keys %h)
      { print "$_\n" }

    untie %h ;

    unlink "tree" ;
  }  

  delete $DB_BTREE->{'compare'} ;

  ok( docat_del($file) eq <<'EOM') ;
mouse
Smith
Wall
EOM
   
  {
    my $redirect = Redirect->new( $file) ;

    # BTREE example 2
    ###

    use warnings FATAL => qw(all) ;
    use strict ;
    use DB_File ;

    my ($filename, %h);

    $filename = "tree" ;
    unlink $filename ;
 
    # Enable duplicate records
    $DB_BTREE->{'flags'} = R_DUP ;
 
    tie %h, "DB_File", $filename, O_RDWR^|^O_CREAT, 0640, $DB_BTREE 
	or die "Cannot open $filename: $!\n";
 
    # Add some key/value pairs to the file
    %h{'Wall'} = 'Larry' ;
    %h{'Wall'} = 'Brick' ; # Note the duplicate key
    %h{'Wall'} = 'Brick' ; # Note the duplicate key and value
    %h{'Smith'} = 'John' ;
    %h{'mouse'} = 'mickey' ;

    # iterate through the associative array
    # and print each key/value pair.
    foreach (keys %h)
      { print "$_	-> %h{$_}\n" }

    untie %h ;

    unlink $filename ;
  }  

  ok( docat_del($file) eq ($db185mode ? <<'EOM' : <<'EOM') ) ;
Smith	-> John
Wall	-> Brick
Wall	-> Brick
Wall	-> Brick
mouse	-> mickey
EOM
Smith	-> John
Wall	-> Larry
Wall	-> Larry
Wall	-> Larry
mouse	-> mickey
EOM

  {
    my $redirect = Redirect->new( $file) ;

    # BTREE example 3
    ###

    use warnings FATAL => qw(all) ;
    use strict ;
    use DB_File ;
 
    my ($filename, $x, %h, $status, $key, $value);

    $filename = "tree" ;
    unlink $filename ;
 
    # Enable duplicate records
    $DB_BTREE->{'flags'} = R_DUP ;
 
    $x = tie %h, "DB_File", $filename, O_RDWR^|^O_CREAT, 0640, $DB_BTREE 
	or die "Cannot open $filename: $!\n";
 
    # Add some key/value pairs to the file
    %h{'Wall'} = 'Larry' ;
    %h{'Wall'} = 'Brick' ; # Note the duplicate key
    %h{'Wall'} = 'Brick' ; # Note the duplicate key and value
    %h{'Smith'} = 'John' ;
    %h{'mouse'} = 'mickey' ;
 
    # iterate through the btree using seq
    # and print each key/value pair.
    $key = $value = 0 ;
    for ($status = $x->seq($key, $value, R_FIRST) ;
         $status == 0 ;
         $status = $x->seq($key, $value, R_NEXT) )
      {  print "$key	-> $value\n" }
 
 
    undef $x ;
    untie %h ;
  }

  ok( docat_del($file) eq ($db185mode == 1 ? <<'EOM' : <<'EOM') ) ;
Smith	-> John
Wall	-> Brick
Wall	-> Brick
Wall	-> Larry
mouse	-> mickey
EOM
Smith	-> John
Wall	-> Larry
Wall	-> Brick
Wall	-> Brick
mouse	-> mickey
EOM


  {
    my $redirect = Redirect->new( $file) ;

    # BTREE example 4
    ###

    use warnings FATAL => qw(all) ;
    use strict ;
    use DB_File ;
 
    my ($filename, $x, %h);

    $filename = "tree" ;
 
    # Enable duplicate records
    $DB_BTREE->{'flags'} = R_DUP ;
 
    $x = tie %h, "DB_File", $filename, O_RDWR^|^O_CREAT, 0640, $DB_BTREE 
	or die "Cannot open $filename: $!\n";
 
    my $cnt  = nelems $x->get_dup("Wall") ;
    print "Wall occurred $cnt times\n" ;

    my %hash = %( < $x->get_dup("Wall", 1) ) ;
    print "Larry is there\n" if %hash{'Larry'} ;
    print "There are %hash{'Brick'} Brick Walls\n" ;

    my @list = @( sort < $x->get_dup("Wall") ) ;
    print "Wall =>	[{join ' ', <@list}]\n" ;

    @list = @( < $x->get_dup("Smith") ) ;
    print "Smith =>	[{join ' ', <@list}]\n" ;
 
    @list = @( < $x->get_dup("Dog") ) ;
    print "Dog =>	[{join ' ', <@list}]\n" ; 
 
    undef $x ;
    untie %h ;
  }

  ok( docat_del($file) eq <<'EOM') ;
Wall occurred 3 times
Larry is there
There are 2 Brick Walls
Wall =>	[Brick Brick Larry]
Smith =>	[John]
Dog =>	[]
EOM

  {
    my $redirect = Redirect->new( $file) ;

    # BTREE example 5
    ###

    use warnings FATAL => qw(all) ;
    use strict ;
    use DB_File ;
 
    my ($filename, $x, %h, $found);

    $filename = "tree" ;
 
    # Enable duplicate records
    $DB_BTREE->{'flags'} = R_DUP ;
 
    $x = tie %h, "DB_File", $filename, O_RDWR^|^O_CREAT, 0640, $DB_BTREE 
	or die "Cannot open $filename: $!\n";

    $found = ( $x->find_dup("Wall", "Larry") == 0 ? "" : "not") ; 
    print "Larry Wall is $found there\n" ;
    
    $found = ( $x->find_dup("Wall", "Harry") == 0 ? "" : "not") ; 
    print "Harry Wall is $found there\n" ;
    
    undef $x ;
    untie %h ;
  }

  ok( docat_del($file) eq <<'EOM') ;
Larry Wall is  there
Harry Wall is not there
EOM

  {
    my $redirect = Redirect->new( $file) ;

    # BTREE example 6
    ###

    use warnings FATAL => qw(all) ;
    use strict ;
    use DB_File ;
 
    my ($filename, $x, %h, $found);

    $filename = "tree" ;
 
    # Enable duplicate records
    $DB_BTREE->{'flags'} = R_DUP ;
 
    $x = tie %h, "DB_File", $filename, O_RDWR^|^O_CREAT, 0640, $DB_BTREE 
	or die "Cannot open $filename: $!\n";

    $x->del_dup("Wall", "Larry") ;

    $found = ( $x->find_dup("Wall", "Larry") == 0 ? "" : "not") ; 
    print "Larry Wall is $found there\n" ;
    
    undef $x ;
    untie %h ;

    unlink $filename ;
  }

  ok( docat_del($file) eq <<'EOM') ;
Larry Wall is not there
EOM

  {
    my $redirect = Redirect->new( $file) ;

    # BTREE example 7
    ###

    use warnings FATAL => qw(all) ;
    use strict ;
    use DB_File ;
    use Fcntl ;

    my ($filename, $x, %h, $st, $key, $value);

    sub match
    {
        my $key = shift ;
        my $value = 0;
        my $orig_key = $key ;
        $x->seq($key, $value, R_CURSOR) ;
        print "$orig_key\t-> $key\t-> $value\n" ;
    }

    $filename = "tree" ;
    unlink $filename ;

    $x = tie %h, "DB_File", $filename, O_RDWR^|^O_CREAT, 0640, $DB_BTREE
        or die "Cannot open $filename: $!\n";
 
    # Add some key/value pairs to the file
    %h{'mouse'} = 'mickey' ;
    %h{'Wall'} = 'Larry' ;
    %h{'Walls'} = 'Brick' ; 
    %h{'Smith'} = 'John' ;
 

    $key = $value = 0 ;
    print "IN ORDER\n" ;
    for ($st = $x->seq($key, $value, R_FIRST) ;
	 $st == 0 ;
         $st = $x->seq($key, $value, R_NEXT) )
	
      {  print "$key	-> $value\n" }
 
    print "\nPARTIAL MATCH\n" ;

    match "Wa" ;
    match "A" ;
    match "a" ;

    undef $x ;
    untie %h ;

    unlink $filename ;

  }

  ok( docat_del($file) eq <<'EOM') ;
IN ORDER
Smith	-> John
Wall	-> Larry
Walls	-> Brick
mouse	-> mickey

PARTIAL MATCH
Wa	-> Wall	-> Larry
A	-> Smith	-> John
a	-> mouse	-> mickey
EOM

}

#{
#   # R_SETCURSOR
#   use strict ;
#   my (%h, $db) ;
#   unlink $Dfile;
#
#   ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR|O_CREAT, 0640, $DB_BTREE ) );
#
#   $h{abc} = 33 ;
#   my $k = "newest" ;
#   my $v = 44 ;
#   my $status = $db->put($k, $v, R_SETCURSOR) ;
#   print "status = [$status]\n" ;
#   ok( $status == 0) ;
#   $status = $db->del($k, R_CURSOR) ;
#   print "status = [$status]\n" ;
#   ok( $status == 0) ;
#   $k = "newest" ;
#   ok( $db->get($k, $v, R_CURSOR)) ;
#
#   ok( keys %h == 1) ;
#   
#   undef $db ;
#   untie %h;
#   unlink $Dfile;
#}

{
    # Bug ID 20001013.009
    #
    # test that $hash{KEY} = undef doesn't produce the warning
    #     Use of uninitialized value in null operation 
    use warnings ;
    use strict ;
    use DB_File ;

    unlink $Dfile;
    my %h ;
    my $a = "";
    local $^WARN_HOOK = sub {$a = @_[0]} ;
    
    tie %h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0664, $DB_BTREE
	or die "Can't open file: $!\n" ;
    %h{ABC} = undef;
    ok( $a eq "") ;
    untie %h ;
    unlink $Dfile;
}

{
    # test that %hash = () doesn't produce the warning
    #     Argument "" isn't numeric in entersub
    use warnings ;
    use strict ;
    use DB_File ;

    unlink $Dfile;
    my %h ;
    my $a = "";
    local $^WARN_HOOK = sub {$a = @_[0]} ;
    
    tie %h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0664, $DB_BTREE
	or die "Can't open file: $!\n" ;
    %h = %( () ); ;
    ok( $a eq "") ;
    untie %h ;
    unlink $Dfile;
}

{
    # When iterating over a tied hash using "each", the key passed to FETCH
    # will be recycled and passed to NEXTKEY. If a Source Filter modifies the
    # key in FETCH via a filter_fetch_key method we need to check that the
    # modified key doesn't get passed to NEXTKEY.
    # Also Test "keys" & "values" while we are at it.

    use warnings ;
    use strict ;
    use DB_File ;

    unlink $Dfile;
    my $bad_key = 0 ;
    my %h = %( () ) ;
    my $db ;
    ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_BTREE ) );
    $db->filter_fetch_key (sub { $_ =~ s/^Beta_/Alpha_/ if defined $_}) ;
    $db->filter_store_key (sub { $bad_key = 1 if m/^Beta_/ ; $_ =~ s/^Alpha_/Beta_/}) ;

    %h{'Alpha_ABC'} = 2 ;
    %h{'Alpha_DEF'} = 5 ;

    ok( %h{'Alpha_ABC'} == 2);
    ok( %h{'Alpha_DEF'} == 5);

    my ($k, $v) = ("","");
    while (($k, $v) = each %h) {}
    ok( $bad_key == 0);

    $bad_key = 0 ;
    foreach $k (keys %h) {}
    ok( $bad_key == 0);

    $bad_key = 0 ;
    foreach $v (values %h) {}
    ok( $bad_key == 0);

    undef $db ;
    untie %h ;
    unlink $Dfile;
}

{
    # now an error to pass 'compare' a non-code reference
    my $dbh = DB_File::BTREEINFO->new() ;

    try { $dbh->{compare} = 2 };
    ok( $@->{description} =~ m/^Key 'compare' not associated with a code reference at/);

    try { $dbh->{prefix} = 2 };
    ok( $@->{description} =~ m/^Key 'prefix' not associated with a code reference at/);

}


#{
#    # recursion detection in btree
#    my %hash ;
#    unlink $Dfile;
#    my $dbh = new DB_File::BTREEINFO ;
#    $dbh->{compare} = sub { $hash{3} = 4 ; length $_[0] } ;
# 
# 
#    my (%h);
#    ok( tie(%hash, 'DB_File',$Dfile, O_RDWR|O_CREAT, 0640, $dbh ) );
#
#    try {	$hash{1} = 2;
#    		$hash{4} = 5;
#	 };
#
#    ok( $@ =~ /^DB_File btree_compare: recursion detected/);
#    {
#        no warnings;
#        untie %hash;
#    }
#    unlink $Dfile;
#}
ok(1);
ok(1);

{
    # Check that two callbacks don't interact
    my %hash1 ;
    my %hash2 ;
    my $h1_count = 0;
    my $h2_count = 0;
    unlink $Dfile, $Dfile2;
    my $dbh1 = DB_File::BTREEINFO->new() ;
    $dbh1->{compare} = sub { ++ $h1_count ; @_[0] cmp @_[1] } ; 

    my $dbh2 = DB_File::BTREEINFO->new() ;
    $dbh2->{compare} = sub { ;++ $h2_count ; @_[0] cmp @_[1] } ; 
 
 
 
    my (%h);
    ok( tie(%hash1, 'DB_File',$Dfile, O_RDWR^|^O_CREAT, 0640, $dbh1 ) );
    ok( tie(%hash2, 'DB_File',$Dfile2, O_RDWR^|^O_CREAT, 0640, $dbh2 ) );

    %hash1{DEFG} = 5;
    %hash1{XYZ} = 2;
    %hash1{ABCDE} = 5;

    %hash2{defg} = 5;
    %hash2{xyz} = 2;
    %hash2{abcde} = 5;

    ok( $h1_count +> 0);
    ok( $h1_count == $h2_count);

    ok( safeUntie \%hash1);
    ok( safeUntie \%hash2);
    unlink $Dfile, $Dfile2;
}

{
   # Check that DBM Filter can cope with read-only $_

   use warnings ;
   use strict ;
   my (%h, $db) ;
   unlink $Dfile;

   ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_BTREE ) );

   $db->filter_fetch_key   (sub { }) ;
   $db->filter_store_key   (sub { }) ;
   $db->filter_fetch_value (sub { }) ;
   $db->filter_store_value (sub { }) ;

   $_ = "original" ;

   %h{"fred"} = "joe" ;
   ok( %h{"fred"} eq "joe");

   try { my @r= @( grep { %h{$_} } (1, 2, 3) ) };
   ok (174, ! $@);


   # delete the filters
   $db->filter_fetch_key   (undef);
   $db->filter_store_key   (undef);
   $db->filter_fetch_value (undef);
   $db->filter_store_value (undef);

   %h{"fred"} = "joe" ;

   ok( %h{"fred"} eq "joe");

   ok( $db->FIRSTKEY() eq "fred") ;
   
   try { my @r= @( grep { %h{$_} } (1, 2, 3) ) };
   ok (177, ! $@);

   undef $db ;
   untie %h;
   unlink $Dfile;
}

{
   # Check low-level API works with filter

   use warnings ;
   use strict ;
   my (%h, $db) ;
   my $Dfile = "xxy.db";
   unlink $Dfile;

   ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_BTREE ) );


   $db->filter_fetch_key   (sub { $_ = unpack("i", $_) } );
   $db->filter_store_key   (sub { $_ = pack("i", $_) } );
   $db->filter_fetch_value (sub { $_ = unpack("i", $_) } );
   $db->filter_store_value (sub { $_ = pack("i", $_) } );

   $_ = 'fred';

   my $key = 22 ;
   my $value = 34 ;

   $db->put($key, $value) ;
   ok 179, $key == 22;
   ok 180, $value == 34 ;
   ok 181, $_ eq 'fred';
   #print "k [$key][$value]\n" ;

   my $val ;
   $db->get($key, $val) ;
   ok 182, $key == 22;
   ok 183, $val == 34 ;
   ok 184, $_ eq 'fred';

   $key = 51 ;
   $value = 454;
   %h{$key} = $value ;
   ok 185, $key == 51;
   ok 186, $value == 454 ;
   ok 187, $_ eq 'fred';

   undef $db ;
   untie %h;
   unlink $Dfile;
}



{
    # Regression Test for bug 30237
    # Check that substr can be used in the key to db_put
    # and that db_put does not trigger the warning
    # 
    #     Use of uninitialized value in subroutine entry


    use warnings ;
    use strict ;
    my (%h, $db) ;
    my $Dfile = "xxy.db";
    unlink $Dfile;

    ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_BTREE ));

    my $warned = '';
    local $^WARN_HOOK = sub {$warned = @_[0]} ;

    # db-put with substr of key
    my %remember = %( () ) ;
    for my $ix ( 10 .. 12 )
    {
        my $key = $ix . "data" ;
        my $value = "value$ix" ;
        %remember{$key} = $value ;
        $db->put(substr($key,0), $value) ;
    }

    ok 189, $warned eq '' 
      or print "# Caught warning [$warned]\n" ;

    # db-put with substr of value
    $warned = '';
    for my $ix ( 20 .. 22 )
    {
        my $key = $ix . "data" ;
        my $value = "value$ix" ;
        %remember{$key} = $value ;
        $db->put($key, substr($value,0)) ;
    }

    ok 190, $warned eq '' 
      or print "# Caught warning [$warned]\n" ;

    # via the tied hash is not a problem, but check anyway
    # substr of key
    $warned = '';
    for my $ix ( 30 .. 32 )
    {
        my $key = $ix . "data" ;
        my $value = "value$ix" ;
        %remember{$key} = $value ;
        %h{substr($key,0)} = $value ;
    }

    ok 191, $warned eq '' 
      or print "# Caught warning [$warned]\n" ;

    # via the tied hash is not a problem, but check anyway
    # substr of value
    $warned = '';
    for my $ix ( 40 .. 42 )
    {
        my $key = $ix . "data" ;
        my $value = "value$ix" ;
        %remember{$key} = $value ;
        %h{$key} = substr($value,0) ;
    }

    ok $warned eq '' 
      or print "# Caught warning [$warned]\n" ;

    my %bad = %( () ) ;
    $key = '';
    for ($status = $db->seq($key, $value, R_FIRST ) ;
         $status == 0 ;
         $status = $db->seq($key, $value, R_NEXT ) ) {

        #print "# key [$key] value [$value]\n" ;
        if (defined %remember{$key} && defined $value && 
             %remember{$key} eq $value) {
            delete %remember{$key} ;
        }
        else {
            %bad{$key} = $value ;
        }
    }
    
    ok nkeys %bad == 0 ;
    ok nkeys %remember == 0 ;

    print "# missing -- $key $value\n" while ($key, $value) = each %remember;
    print "# bad     -- $key $value\n" while ($key, $value) = each %bad;

    # Make sure this fix does not break code to handle an undef key
    # Berkeley DB undef key is bron between versions 2.3.16 and 
    my $value = 'fred';
    $warned = '';
    $db->put(undef, $value) ;
    ok $warned eq '' 
      or print "# Caught warning [$warned]\n" ;
    $warned = '';

    my $no_NULL = ($DB_File::db_ver +>= 2.003016 && $DB_File::db_ver +< 3.001) ;
    print "# db_ver $DB_File::db_ver\n";
    $value = '' ;
    $db->get(undef, $value) ;
    ok $no_NULL || $value eq 'fred' or print "# got [$value]\n" ;
    ok $warned eq '' 
      or print "# Caught warning [$warned]\n" ;
    $warned = '';

    undef $db ;
    untie %h;
    unlink $Dfile;
}
exit ;
