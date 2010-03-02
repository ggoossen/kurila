#!./perl -w

use warnings

use Config

use DB_File
use Fcntl
our ($dbh, $Dfile, $bad_ones, $FA)

sub ok
    my $no = shift 
    my $result = shift 

    print: $^STDOUT, "not " unless $result 
    print: $^STDOUT, "ok $no\n" 

    return $result 


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
    (open: my $catfh, "<",$file) || die: "Cannot open $file:$^OS_ERROR"
    my $result = ~< $catfh->*
    close: $catfh
    normalise: $result 
    return $result


sub docat_del
    my $file = shift
    my $result = docat: $file
    unlink: $file 
    return $result


sub bad_one
    unless ($bad_ones++)
        print: $^STDERR, <<EOM 
#
# Some older versions of Berkeley DB version 1 will fail db-recno
# tests 61, 63, 64 and 65.
EOM
        if ($^OS_NAME eq 'darwin'
              && (config_value: "db_version_major") == 1
              && (config_value: "db_version_minor") == 0
              && (config_value: "db_version_patch") == 0)
            print: $^STDERR, <<EOM 
#
# For example Mac OS X 10.2 (or earlier) has such an old
# version of Berkeley DB.
EOM
        

        print: $^STDERR, <<EOM 
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
    


sub normalise
    return unless $^OS_NAME eq 'cygwin' 
    foreach ( @_)
        s#\r\n#\n#g


BEGIN 

    do
        try { require Data::Dumper ; (Data::Dumper->import: ) } 
    

    if ($^EVAL_ERROR)
        *Dumper = sub (@< @_) { my $a = shift; return "[ $((join: ' ', $a->@)) ]" } 
    


my $total_tests = 14 
print: $^STDOUT, "1..$total_tests\n"

$Dfile = "recno.tmp"
unlink: $Dfile 

umask: 0

# Check the interface to RECNOINFO

$dbh = DB_File::RECNOINFO->new:  
ok: 1, ! defined $dbh->{?bval} 
ok: 2, ! defined $dbh->{?cachesize} 
ok: 3, ! defined $dbh->{?psize} 
ok: 4, ! defined $dbh->{?flags} 
ok: 5, ! defined $dbh->{?lorder} 
ok: 6, ! defined $dbh->{?reclen} 
ok: 7, ! defined $dbh->{?bfname} 

$dbh->{+bval} = 3000 
ok: 8, $dbh->{?bval} == 3000 

$dbh->{+cachesize} = 9000 
ok: 9, $dbh->{?cachesize} == 9000 

$dbh->{+psize} = 400 
ok: 10, $dbh->{?psize} == 400 

$dbh->{+flags} = 65 
ok: 11, $dbh->{?flags} == 65 

$dbh->{+lorder} = 123 
ok: 12, $dbh->{?lorder} == 123 

$dbh->{+reclen} = 1234 
ok: 13, $dbh->{?reclen} == 1234 

$dbh->{+bfname} = 1234 
ok: 14, $dbh->{?bfname} == 1234 


# Now check the interface to RECNOINFO

