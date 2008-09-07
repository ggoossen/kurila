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

use DB_File; 
use Fcntl;
our ($dbh, $Dfile, $bad_ones, $FA);

sub ok
{
    my $no = shift ;
    my $result = shift ;

    print "not " unless $result ;
    print "ok $no\n" ;

    return $result ;
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
    local $/ = undef;
    open(CAT, "<",$file) || die "Cannot open $file:$!";
    my $result = ~< *CAT;
    close(CAT);
    normalise($result) ;
    return $result;
}

sub docat_del
{ 
    my $file = shift;
    my $result = docat($file);
    unlink $file ;
    return $result;
}   

sub safeUntie
{
    my $hashref = shift ;
    my $no_inner = 1;
    local $^WARN_HOOK = sub {-- $no_inner } ;
    untie @$hashref;
    return $no_inner;
}

sub bad_one
{
    unless ($bad_ones++) {
	print STDERR <<EOM ;
#
# Some older versions of Berkeley DB version 1 will fail db-recno
# tests 61, 63, 64 and 65.
EOM
        if ($^O eq 'darwin'
	    && %Config{db_version_major} == 1
	    && %Config{db_version_minor} == 0
	    && %Config{db_version_patch} == 0) {
	    print STDERR <<EOM ;
#
# For example Mac OS X 10.2 (or earlier) has such an old
# version of Berkeley DB.
EOM
	}

	print STDERR <<EOM ;
#
# You can safely ignore the errors if you're never going to use the
# broken functionality (recno databases with a modified bval). 
# Otherwise you'll have to upgrade your DB library.
#
# If you want to use Berkeley DB version 1, then 1.85 and 1.86 are the
# last versions that were released. Berkeley DB version 2 is continually
# being updated -- Check out http://www.sleepycat.com/ for more details.
#
EOM
    }
}

sub normalise
{
    return unless $^O eq 'cygwin' ;
    foreach ( @_)
      { s#\r\n#\n#g }     
}

BEGIN 
{ 
    { 
        try { require Data::Dumper ; Data::Dumper->import() } ; 
    }
 
    if ($@) {
        *Dumper = sub { my $a = shift; return "[ {join ' ',@{ $a }} ]" } ;
    }          
}

my $total_tests = 16 ;
print "1..$total_tests\n";   

$Dfile = "recno.tmp";
unlink $Dfile ;

umask(0);

# Check the interface to RECNOINFO

$dbh = DB_File::RECNOINFO->new() ;
ok(1, ! defined $dbh->{bval}) ;
ok(2, ! defined $dbh->{cachesize}) ;
ok(3, ! defined $dbh->{psize}) ;
ok(4, ! defined $dbh->{flags}) ;
ok(5, ! defined $dbh->{lorder}) ;
ok(6, ! defined $dbh->{reclen}) ;
ok(7, ! defined $dbh->{bfname}) ;

$dbh->{bval} = 3000 ;
ok(8, $dbh->{bval} == 3000 );

$dbh->{cachesize} = 9000 ;
ok(9, $dbh->{cachesize} == 9000 );

$dbh->{psize} = 400 ;
ok(10, $dbh->{psize} == 400 );

$dbh->{flags} = 65 ;
ok(11, $dbh->{flags} == 65 );

$dbh->{lorder} = 123 ;
ok(12, $dbh->{lorder} == 123 );

$dbh->{reclen} = 1234 ;
ok(13, $dbh->{reclen} == 1234 );

$dbh->{bfname} = 1234 ;
ok(14, $dbh->{bfname} == 1234 );


# Check that an invalid entry is caught both for store & fetch
eval '$dbh->{fred} = 1234' ;
ok(15, $@->{description} =~ m/^DB_File::RECNOINFO::STORE - Unknown element 'fred' at/ );
eval 'my $q = $dbh->{fred}' ;
ok(16, $@->{description} =~ m/^DB_File::RECNOINFO::FETCH - Unknown element 'fred' at/ );

# Now check the interface to RECNOINFO

