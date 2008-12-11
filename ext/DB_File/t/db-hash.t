#!./perl 

use warnings;

use Config;
 
use DB_File; 
use Fcntl;

use Test::More;

plan tests => 165;

unlink < glob "__db.*";

do {
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
};

sub docat_del
{ 
    my $file = shift;
    local $/ = undef;
    open(CAT, "<",$file) || die "Cannot open $file: $!";
    my $result = ~< *CAT;
    close(CAT);
    $result = normalise($result) ;
    unlink $file ;
    return $result;
}   

sub normalise
{
    my $data = shift ;
    $data =~ s#\r\n#\n#g 
        if $^O eq 'cygwin' ;
    return $data ;
}

my $Dfile = "dbhash.tmp";
my $Dfile2 = "dbhash2.tmp";
my $null_keys_allowed = ($DB_File::db_ver +< 2.004010 
				|| $DB_File::db_ver +>= 3.1 );

unlink $Dfile;

umask(0);

# Check the interface to HASHINFO

my $dbh = DB_File::HASHINFO->new() ;

ok( ! defined $dbh->{?bsize}) ;
ok( ! defined $dbh->{?ffactor}) ;
ok( ! defined $dbh->{?nelem}) ;
ok( ! defined $dbh->{?cachesize}) ;
ok( ! defined $dbh->{?hash}) ;
ok( ! defined $dbh->{?lorder}) ;

$dbh->{+bsize} = 3000 ;
ok( $dbh->{?bsize} == 3000 );

$dbh->{+ffactor} = 9000 ;
ok( $dbh->{?ffactor} == 9000 );

$dbh->{+nelem} = 400 ;
ok( $dbh->{?nelem} == 400 );

$dbh->{+cachesize} = 65 ;
ok( $dbh->{?cachesize} == 65 );

my $some_sub = sub {} ;
$dbh->{+hash} = $some_sub;
ok( $dbh->{?hash} \== $some_sub );

$dbh->{+lorder} = 1234 ;
ok( $dbh->{?lorder} == 1234 );


# Now check the interface to HASH
my %h = DB_File->new($Dfile, O_RDWR^|^O_CREAT, 0640, $DB_HASH );
ok( %h);

my @($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
   $blksize,$blocks) = @: stat($Dfile);

my %noMode = %( < map { $_, 1} qw( amigaos MSWin32 NetWare cygwin ) ) ;

ok( ($mode ^&^ 0777) == (($^O eq 'os2' || $^O eq 'MacOS') ?? 0666 !! 0640) ||
   %noMode{?$^O} );

my ($key, $value, $i);
# while (@(?$key,?$value) = @: each(%h)) {
#     $i++;
# }
ok( !$i );

%h->put('goner1', 'snork');

%h->put('abc', 'ABC');
is( %h->FETCH("abc"), 'ABC' );
is( %h->FETCH("jimmy"), undef );

%h->put('def', 'DEF');
%h->put('jkl' . "\034" . 'mno', "JKL\034MNO");
%h->put(join("\034", @: 'a',2,3,4,5), join("\034", @:'A',2,3,4,5));
%h->put('a', 'A');
%h->put('b', 'B');
%h->put('c', 'C');
%h->put('d', 'D') ;
for (qw|e f g h i|) {
    %h->put($_, uc($_));
}

%h->put('goner2', 'snork');
%h->DELETE('goner2');

# IMPORTANT - $X must be undefined before the untie otherwise the
#             underlying DB close routine will not get called.
%h = undef;


# tie to the same file again, do not supply a type - should default to HASH
%h = DB_File->new($Dfile, O_RDWR, 0640);
ok(%h);

# Modify an entry from the previous tie
for (qw(g j k l m n o p q r s t u v w x y z)) {
    %h->put($_, uc($_));
}

%h->del('goner1');

my @keys = %h->keys;
my @values = %h->values;

is( nelems(@keys), 30 );
is( nelems(@values), 30 );

$i = 0 ;
%h->iterate(
    sub {
        my @($key,$value) = @_;
        if ($key eq @keys[$i] && $value eq @values[$i] && $key eq lc($value)) {
            $key = uc($key);
            $i++ if $key eq $value;
        }
    }
);

ok( $i == 30) ;

@keys = @('blurfl', < %h->keys, 'dyick');
ok( (nelems @keys) == 32) ;

%h->STORE('foo' => '');
ok( %h->FETCH('foo') eq '' );

# Berkeley DB from version 2.4.10 to 3.0 does not allow null keys.
# This feature was reenabled in version 3.1 of Berkeley DB.
my $result = 0 ;
if ($null_keys_allowed) {
    %h->STORE('' => 'bar');
    $result = ( %h->FETCH('') eq 'bar' );
}
else
  { $result = 1 }
ok( $result) ;

# check cache overflow and numeric keys and contents
my $ok = 1;
for my $i (1..199) { %h->put( $i + 0 => $i + 0 ); }
for my $i (1..199) { $ok = 0 unless %h->FETCH($i) == $i; }
ok( $ok );

@($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,$atime,$mtime,$ctime,
   $blksize,$blocks) = @: stat($Dfile);
ok( $size +> 0 );

# Now check all the non-tie specific stuff

# Check NOOVERWRITE will make put fail when attempting to overwrite
# an existing record.
 
my $status = %h->put( 'x', 'newvalue', R_NOOVERWRITE) ;
ok( $status == 1 );
 
# check that the value of the key 'x' has not been changed by the 
# previous test
ok( %h->FETCH('x') eq 'X' );

# standard put
$status = %h->put('key', 'value') ;
ok( $status == 0 );

#check that previous put can be retrieved
$value = 0 ;
$status = %h->get('key', $value) ;
ok( $status == 0 );
ok( $value eq 'value' );

# Attempting to delete an existing key should work

$status = %h->del('q') ;
ok( $status == 0 );

# Make sure that the key deleted, cannot be retrieved
do {
    no warnings 'uninitialized' ;
    ok( %h->FETCH('q') eq undef );
};

# Attempting to delete a non-existant key should fail

$status = %h->del('joe') ;
ok( $status == 1 );

# Check the get interface

# First a non-existing key
$status = %h->get('aaaa', $value) ;
ok( $status == 1 );

# Next an existing key
$status = %h->get('a', $value) ;
ok( $status == 0 );
ok( $value eq 'A' );

# seq
# ###

# ditto, but use put to replace the key/value pair.

# use seq to walk backwards through a file - check that this reversed is

# check seq FIRST/LAST

# sync
# ####

$status = %h->sync ;
ok( $status == 0 );


# fd
# ##

$status = %h->fd ;
ok( 1 );
#ok( $status != 0 );

undef %h ;

unlink $Dfile;

do {
    # check ability to override the default hashing
    my $filename = "xyz" ;
    my $hi = DB_File::HASHINFO->new() ;
    $::count = 0 ;
    $hi->{+hash} = sub { ++$::count ; length @_[0] } ;
    my %h = DB_File->new( $filename, O_RDWR^|^O_CREAT, 0640, $hi ) ;
    %h->put("abc", 123 );
    my $value;
    %h->get("abc", $value);
    ok( $value == 123) ;
    unlink $filename ;
    ok( $::count +>0) ;
};

ok( 1);

do {
   # sub-class test

   package Another ;

   use warnings ;
    

   open(FILE, ">", "SubDB.pm") or die "Cannot open SubDB.pm: $!\n" ;
   print FILE <<'EOM' ;

   package SubDB ;

   use warnings ;
   our (@ISA, @EXPORT);

   require Exporter ;
   use DB_File;
   @ISA=qw(DB_File);
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
    eval '
	%h = tie(%h, "SubDB","dbhash.tmp", O_RDWR^|^O_CREAT, 0640, $DB_HASH );
	' ;

    main::ok( $@ eq "") ;

    my $ret = eval '%h{+"fred"} = 3 ; return %h{"fred"} ' ;
    die if $@;
    main::ok( ! $@ ) ;
    main::ok( $ret == 5) ;

    my $value = 0;
    $ret = eval '%h->put("joe", 4) ; %h->get("joe", $value) ; return $value' ;
    main::ok( ! $@ ) ;
    main::ok( $ret == 10) ;

    $ret = eval ' R_NEXT eq main::R_NEXT ' ;
    main::ok( $@ eq "" ) ;
    main::ok( $ret == 1) ;

    $ret = eval '%h->A_new_method("joe") ' ;
    main::ok( $@ eq "") ;
    main::ok( $ret eq "[[11]]") ;

    undef %h;
    untie(%h);
    unlink "SubDB.pm", "dbhash.tmp" ;

};

do {
   # DBM Filter tests
   use warnings ;
    
   my (%h, $db) ;
   my @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   unlink $Dfile;

   sub checkOutput
   {
       no warnings 'uninitialized';
       my@($fk, $sk, $fv, $sv) =  @_ ;

       print "# Fetch Key   : expected '$fk' got '$fetch_key'\n" 
           if $fetch_key ne $fk ;
       print "# Fetch Value : expected '$fv' got '$fetch_value'\n" 
           if $fetch_value ne $fv ;
       print "# Store Key   : expected '$sk' got '$store_key'\n" 
           if $store_key ne $sk ;
       print "# Store Value : expected '$sv' got '$store_value'\n" 
           if $store_value ne $sv ;
       print "# \$_          : expected 'original' got '$_'\n" 
           if $_ ne 'original' ;

       return
           $fetch_key   eq $fk && $store_key   eq $sk && 
	   $fetch_value eq $fv && $store_value eq $sv &&
	   $_ eq 'original' ;
   }
   
   ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_HASH ) );

   $db->filter_fetch_key   (sub { $fetch_key = $_ }) ;
   $db->filter_store_key   (sub { $store_key = $_ }) ;
   $db->filter_fetch_value (sub { $fetch_value = $_}) ;
   $db->filter_store_value (sub { $store_value = $_ }) ;

   $_ = "original" ;

   %h{+"fred"} = "joe" ;
   #                   fk   sk     fv   sv
   ok( checkOutput( "", "fred", "", "joe")) ;

   @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   ok( %h{?"fred"} eq "joe");
   #                   fk    sk     fv    sv
   ok( checkOutput( "", "fred", "joe", "")) ;

   @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   my ($k, $v) ;
   $k = 'fred';
   ok( ! $db->seq($k, $v, R_FIRST) ) ;
   ok( $k eq "fred") ;
   ok( $v eq "joe") ;
   #                    fk     sk  fv  sv
   ok( checkOutput( "fred", "fred", "joe", "")) ;

   # replace the filters, but remember the previous set
   my $old_fk = $db->filter_fetch_key   
   			(sub { $_ = uc $_ ; $fetch_key = $_ }) ;
   my $old_sk = $db->filter_store_key   
   			(sub { $_ = lc $_ ; $store_key = $_ }) ;
   my $old_fv = $db->filter_fetch_value 
   			(sub { $_ = "[$_]"; $fetch_value = $_ }) ;
   my $old_sv = $db->filter_store_value 
   			(sub { s/o/x/g; $store_value = $_ }) ;
   
   @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   %h{+"Fred"} = "Joe" ;
   #                   fk   sk     fv    sv
   ok( checkOutput( "", "fred", "", "Jxe")) ;

   @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   ok( %h{?"Fred"} eq "[Jxe]");
   #                   fk   sk     fv    sv
   ok( checkOutput( "", "fred", "[Jxe]", "")) ;

   @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   $k = 'Fred'; $v ='';
   ok( ! $db->seq($k, $v, R_FIRST) ) ;
   ok( $k eq "FRED") or 
    print "# k [$k]\n" ;
   ok( $v eq "[Jxe]") ;
   #                   fk   sk     fv    sv
   ok( checkOutput( "FRED", "fred", "[Jxe]", "")) ;

   # put the original filters back
   $db->filter_fetch_key   ($old_fk);
   $db->filter_store_key   ($old_sk);
   $db->filter_fetch_value ($old_fv);
   $db->filter_store_value ($old_sv);

   @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   %h{+"fred"} = "joe" ;
   ok( checkOutput( "", "fred", "", "joe")) ;

   @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   ok( %h{?"fred"} eq "joe");
   ok( checkOutput( "", "fred", "joe", "")) ;

   @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   #ok( $db->FIRSTKEY() eq "fred") ;
   $k = 'fred';
   ok( ! $db->seq($k, $v, R_FIRST) ) ;
   ok( $k eq "fred") ;
   ok( $v eq "joe") ;
   #                   fk   sk     fv    sv
   ok( checkOutput( "fred", "fred", "joe", "")) ;

   # delete the filters
   $db->filter_fetch_key   (undef);
   $db->filter_store_key   (undef);
   $db->filter_fetch_value (undef);
   $db->filter_store_value (undef);

   @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   %h{+"fred"} = "joe" ;
   ok( checkOutput( "", "", "", "")) ;

   @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   ok( %h{?"fred"} eq "joe");
   ok( checkOutput( "", "", "", "")) ;

   @($fetch_key, $store_key, $fetch_value, $store_value) = @("") x 4 ;
   $k = 'fred';
   ok( ! $db->seq($k, $v, R_FIRST) ) ;
   ok( $k eq "fred") ;
   ok( $v eq "joe") ;
   ok( checkOutput( "", "", "", "")) ;

   undef $db ;
   undef %h;
   unlink $Dfile;
};

do {    
    # DBM Filter with a closure

    use warnings ;
     
    my (%h, $db) ;

    unlink $Dfile;
    ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_HASH ) );

    my %result = %( () ) ;

    sub Closure
    {
        my @($name) =  @_ ;
	my $count = 0 ;
	my @kept = @( () ) ;

	return sub { ++$count ; 
		     push @kept, $_ ; 
		     %result{+$name} = "$name - $count: [$(join ' ',@kept)]" ;
		   }
    }

    $db->filter_store_key(Closure("store key")) ;
    $db->filter_store_value(Closure("store value")) ;
    $db->filter_fetch_key(Closure("fetch key")) ;
    $db->filter_fetch_value(Closure("fetch value")) ;

    $_ = "original" ;

    %h{+"fred"} = "joe" ;
    ok( %result{?"store key"} eq "store key - 1: [fred]");
    ok( %result{?"store value"} eq "store value - 1: [joe]");
    ok( ! defined %result{?"fetch key"} );
    ok( ! defined %result{?"fetch value"} );
    ok( $_ eq "original") ;

    ok( $db->FIRSTKEY() eq "fred") ;
    ok( %result{?"store key"} eq "store key - 1: [fred]");
    ok( %result{?"store value"} eq "store value - 1: [joe]");
    ok( %result{?"fetch key"} eq "fetch key - 1: [fred]");
    ok( ! defined %result{?"fetch value"} );
    ok( $_ eq "original") ;

    %h{+"jim"}  = "john" ;
    ok( %result{?"store key"} eq "store key - 2: [fred jim]");
    ok( %result{?"store value"} eq "store value - 2: [joe john]");
    ok( %result{?"fetch key"} eq "fetch key - 1: [fred]");
    ok( ! defined %result{?"fetch value"} );
    ok( $_ eq "original") ;

    ok( %h{?"fred"} eq "joe");
    ok( %result{?"store key"} eq "store key - 3: [fred jim fred]");
    ok( %result{?"store value"} eq "store value - 2: [joe john]");
    ok( %result{?"fetch key"} eq "fetch key - 1: [fred]");
    ok( %result{?"fetch value"} eq "fetch value - 1: [joe]");
    ok( $_ eq "original") ;

    undef $db ;
    undef %h;
    unlink $Dfile;
};		

do {
   # DBM Filter recursion detection
   use warnings ;
    
   my (%h, $db) ;
   unlink $Dfile;

   ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_HASH ) );

   $db->filter_store_key (sub { $_ = %h{?$_} }) ;

   eval '%h{1} = 1234' ;
   ok( $@->{?description} =~ m/^recursion detected in filter_store_key/ );
   
   undef $db ;
   undef %h;
   unlink $Dfile;
};


do {
   # Examples from the POD

  my $file = "xyzt" ;
  do {
    my $redirect = Redirect->new( $file) ;

    use warnings FATAL => < qw(all);
     
    use DB_File ;
    our ($k, $v);

    unlink "fruit" ;
    my %h = DB_File->new( "fruit", O_RDWR^|^O_CREAT, 0640, $DB_HASH )
        or die "Cannot open file 'fruit': $!\n";

    # Add a few key/value pairs to the file
    %h->put("apple" => "red");
    %h->put("orange" => "orange");
    %h->put("banana" => "yellow");
    %h->put("tomato" => "red");

    # Check for existence of a key
    print "Banana Exists\n\n" if %h->FETCH("banana") ;

    # Delete a key/value pair.
    %h->del("apple") ;

    # print the contents of the file
    while (@(?$k, ?$v) =@( each %h))
      { print "$k -> $v\n" }

    undef %h ;

    unlink "fruit" ;
  };  

  ok( docat_del($file) eq <<'EOM') ;
Banana Exists

orange -> orange
tomato -> red
banana -> yellow
EOM
   
};

do {
    # Bug ID 20001013.009
    #
    # test that $hash{KEY} = undef doesn't produce the warning
    #     Use of uninitialized value in null operation 
    use warnings ;
     
    use DB_File ;

    unlink $Dfile;
    my $a = "";
    local $^WARN_HOOK = sub {$a = @_[0]} ;
    
    my %h = DB_File->new( $Dfile ) or die "Can't open file: $!\n" ;
    %h->put("ABC" => undef);
    ok( $a eq "") ;
    undef %h;
    unlink $Dfile;
};

do {
    # test that %hash = () doesn't produce the warning
    #     Argument "" isn't numeric in entersub
    use warnings ;
     
    use DB_File ;

    unlink $Dfile;
    my $a = "";
    local $^WARN_HOOK = sub {$a = @_[0]} ;
    
    my %h = DB_File->new($Dfile) or die "Can't open file: $!\n" ;
    %h->clear();
    ok( $a eq "") ;
    undef %h;
    unlink $Dfile;
};

do {
    # When iterating over a tied hash using "each", the key passed to FETCH
    # will be recycled and passed to NEXTKEY. If a Source Filter modifies the
    # key in FETCH via a filter_fetch_key method we need to check that the
    # modified key doesn't get passed to NEXTKEY.
    # Also Test "keys" & "values" while we are at it.

    use warnings ;
     
    use DB_File ;

    unlink $Dfile;
    my $bad_key = 0 ;
    my %h = %( () ) ;
    my $db ;
    ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_HASH ) );
    $db->filter_fetch_key (sub { $_ =~ s/^Beta_/Alpha_/ if defined $_}) ;
    $db->filter_store_key (sub { $bad_key = 1 if m/^Beta_/ ; $_ =~ s/^Alpha_/Beta_/}) ;

    %h{+'Alpha_ABC'} = 2 ;
    %h{+'Alpha_DEF'} = 5 ;

    ok( %h{?'Alpha_ABC'} == 2);
    ok( %h{?'Alpha_DEF'} == 5);

    my @($k, $v) = @("","");
    while (@(?$k, ?$v) =@( each %h)) {}
    ok( $bad_key == 0);

    $bad_key = 0 ;
    foreach my $k (keys %h) {}
    ok( $bad_key == 0);

    $bad_key = 0 ;
    foreach my $v (values %h) {}
    ok( $bad_key == 0);

    undef $db ;
    undef %h ;
    unlink $Dfile;
};

do {
    # now an error to pass 'hash' a non-code reference
    my $dbh = DB_File::HASHINFO->new() ;

    dies_like( sub { $dbh->{+hash} = 2 },
               qr/^Key 'hash' not associated with a code reference/ );

};


#{
#    # recursion detection in hash
#    my %hash ;
#    my $Dfile = "xxx.db";
#    unlink $Dfile;
#    my $dbh = new DB_File::HASHINFO ;
#    $dbh->{hash} = sub { $hash{3} = 4 ; length $_[0] } ;
# 
# 
#    ok( tie(%hash, 'DB_File',$Dfile, O_RDWR|O_CREAT, 0640, $dbh ) );
#
#    try {	$hash{1} = 2;
#    		$hash{4} = 5;
#	 };
#
#    ok( $@ =~ /^DB_File hash callback: recursion detected/);
#    {
#        no warnings;
#        untie %hash;
#    }
#    unlink $Dfile;
#}

#ok( 1);
#ok( 1);

do {
    # Check that two hash's don't interact
    my %hash1 ;
    my %hash2 ;
    my $h1_count = 0;
    my $h2_count = 0;
    unlink $Dfile, $Dfile2;
    my $dbh1 = DB_File::HASHINFO->new() ;
    $dbh1->{+hash} = sub { ++ $h1_count ; length @_[0] } ;

    my $dbh2 = DB_File::HASHINFO->new() ;
    $dbh2->{+hash} = sub { ++ $h2_count ; length @_[0] } ;
 
 
 
    my (%h);
    ok( tie(%hash1, 'DB_File',$Dfile, O_RDWR^|^O_CREAT, 0640, $dbh1 ) );
    ok( tie(%hash2, 'DB_File',$Dfile2, O_RDWR^|^O_CREAT, 0640, $dbh2 ) );

    %hash1{+DEFG} = 5;
    %hash1{+XYZ} = 2;
    %hash1{+ABCDE} = 5;

    %hash2{+defg} = 5;
    %hash2{+xyz} = 2;
    %hash2{+abcde} = 5;

    ok( $h1_count +> 0);
    ok( $h1_count == $h2_count);

    unlink $Dfile, $Dfile2;
};

do {
    # Passing undef for flags and/or mode when calling tie could cause 
    #     Use of uninitialized value in subroutine entry
    

    my $warn_count = 0 ;
    #local $SIG{__WARN__} = sub { ++ $warn_count };
    my %hash1;
    unlink $Dfile;

    tie %hash1, 'DB_File',$Dfile, undef;
    ok( $warn_count == 0);
    $warn_count = 0;
    untie %hash1;
    unlink $Dfile;
    tie %hash1, 'DB_File',$Dfile, O_RDWR^|^O_CREAT, undef;
    ok( $warn_count == 0);
    untie %hash1;
    unlink $Dfile;
    tie %hash1, 'DB_File',$Dfile, undef, undef;
    ok( $warn_count == 0);
    $warn_count = 0;

    untie %hash1;
    unlink $Dfile;
};

do {
   # Check that DBM Filter can cope with read-only $_

   use warnings ;
    
   my (%h, $db) ;
   my $Dfile = "xxy.db";
   unlink $Dfile;

   ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_HASH ) );

   $db->filter_fetch_key   (sub { }) ;
   $db->filter_store_key   (sub { }) ;
   $db->filter_fetch_value (sub { }) ;
   $db->filter_store_value (sub { }) ;

   $_ = "original" ;

   %h{+"fred"} = "joe" ;
   ok( %h{?"fred"} eq "joe");

   my @r= grep { %h{?$_} } @( (1, 2, 3));

   # delete the filters
   $db->filter_fetch_key   (undef);
   $db->filter_store_key   (undef);
   $db->filter_fetch_value (undef);
   $db->filter_store_value (undef);

   %h{+"fred"} = "joe" ;

   ok( %h{?"fred"} eq "joe");

   ok( $db->FIRSTKEY() eq "fred") ;
   
   try { my @r= grep { %h{?$_} } @( (1, 2, 3)) };
   ok (141, ! $@);

   undef $db ;
   untie %h;
   unlink $Dfile;
};

do {
   # Check low-level API works with filter

   use warnings ;
    
   my (%h, $db) ;
   my $Dfile = "xxy.db";
   unlink $Dfile;

   ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_HASH ) );


   $db->filter_fetch_key   (sub { $_ = unpack("i", $_) } );
   $db->filter_store_key   (sub { $_ = pack("i", $_) } );
   $db->filter_fetch_value (sub { $_ = unpack("i", $_) } );
   $db->filter_store_value (sub { $_ = pack("i", $_) } );

   $_ = 'fred';

   my $key = 22 ;
   my $value = 34 ;

   $db->put($key, $value) ;
   ok $key == 22;
   ok $value == 34 ;
   ok $_ eq 'fred';
   #print "k [$key][$value]\n" ;

   my $val ;
   $db->get($key, $val) ;
   ok $key == 22;
   ok $val == 34 ;
   ok $_ eq 'fred';

   $key = 51 ;
   $value = 454;
   %h{+$key} = $value ;
   ok $key == 51;
   ok $value == 454 ;
   ok $_ eq 'fred';

   undef $db ;
   untie %h;
   unlink $Dfile;
};


do {
    # Regression Test for bug 30237
    # Check that substr can be used in the key to db_put
    # and that db_put does not trigger the warning
    # 
    #     Use of uninitialized value in subroutine entry


    use warnings ;
     
    my (%h, $db) ;
    my $Dfile = "xxy.db";
    unlink $Dfile;

    ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_HASH ) );

    my $warned = '';
    local $^WARN_HOOK = sub {$warned = @_[0]} ;

    # db-put with substr of key
    my %remember = %( () ) ;
    for my $ix ( 1 .. 2 )
    {
        my $key = $ix . "data" ;
        my $value = "value$ix" ;
        %remember{+$key} = $value ;
        $db->put($key, $value) ;
    }

    ok $warned eq '' 
      or print "# Caught warning [$warned]\n" ;

    # db-put with substr of value
    $warned = '';
    for my $ix ( 10 .. 12 )
    {
        my $key = $ix . "data" ;
        my $value = "value$ix" ;
        %remember{+$key} = $value ;
        $db->put($key, $value) ;
    }

    ok $warned eq '' 
      or print "# Caught warning [$warned]\n" ;

    # via the tied hash is not a problem, but check anyway
    # substr of key
    $warned = '';
    for my $ix ( 30 .. 32 )
    {
        my $key = $ix . "data" ;
        my $value = "value$ix" ;
        %remember{+$key} = $value ;
        %h{+substr($key,0)} = $value ;
    }

    ok $warned eq '' 
      or print "# Caught warning [$warned]\n" ;

    # via the tied hash is not a problem, but check anyway
    # substr of value
    $warned = '';
    for my $ix ( 40 .. 42 )
    {
        my $key = $ix . "data" ;
        my $value = "value$ix" ;
        %remember{+$key} = $value ;
        %h{+$key} = substr($value,0) ;
    }

    ok $warned eq '' 
      or print "# Caught warning [$warned]\n" ;

    my %bad = %( () ) ;
    $key = '';
    my $status = $db->seq($key, $value, R_FIRST );
    while ( $status == 0 ) {

        #print "# key [$key] value [$value]\n" ;
        if (defined %remember{?$key} && defined $value && 
             %remember{?$key} eq $value) {
            delete %remember{$key} ;
        }
        else {
            %bad{+$key} = $value ;
        }

        $status = $db->seq($key, $value, R_NEXT );
    }
    
    ok nkeys %bad == 0 ;
    ok nkeys %remember == 0 ;

    print "# missing -- $key=>$value\n" while @(?$key, ?$value) =@( each %remember);
    print "# bad     -- $key=>$value\n" while @(?$key, ?$value) =@( each %bad);

    # Make sure this fix does not break code to handle an undef key
    # Berkeley DB undef key is broken between versions 2.3.16 and 3.1
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
};

do {
   # Check filter + substr

   use warnings ;
    
   my (%h, $db) ;
   my $Dfile = "xxy.db";
   unlink $Dfile;

   ok( $db = tie(%h, 'DB_File', $Dfile, O_RDWR^|^O_CREAT, 0640, $DB_HASH ) );


   do {
       $db->filter_fetch_key   (sub { lc $_ } );
       $db->filter_store_key   (sub { uc $_ } );
       $db->filter_fetch_value (sub { lc $_ } );
       $db->filter_store_value (sub { uc $_ } );
   };

   $_ = 'fred';

    # db-put with substr of key
    my %remember = %( () ) ;
    my $status = 0 ;
    for my $ix ( 1 .. 2 )
    {
        my $key = $ix . "data" ;
        my $value = "value$ix" ;
        %remember{+$key} = $value ;
        $status += $db->put(substr($key,0), substr($value,0)) ;
    }

    ok $status == 0 or print "# Status $status\n" ;

    if (1)
    {
       $db->filter_fetch_key   (undef);
       $db->filter_store_key   (undef);
       $db->filter_fetch_value (undef);
       $db->filter_store_value (undef);
    }

    my %bad = %( () ) ;
    my $key = '';
    my $value = '';
   $status = $db->seq($key, $value, R_FIRST );
   while ( $status == 0 ) {

        #print "# key [$key] value [$value]\n" ;
        if (defined %remember{?$key} && defined $value && 
             %remember{?$key} eq $value) {
            delete %remember{$key} ;
        }
        else {
            %bad{+$key} = $value ;
        }

        $status = $db->seq($key, $value, R_NEXT );
    }
    
    ok $_ eq 'fred';
    ok nkeys %bad == 0 ;
    ok nkeys %remember == 0 ;

    print "# missing -- $key $value\n" while @(?$key, ?$value) =@( each %remember);
    print "# bad     -- $key $value\n" while @(?$key, ?$value) =@( each %bad);
   undef $db ;
   untie %h;
   unlink $Dfile;
};

exit ;
