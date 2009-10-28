
use warnings

use ExtUtils::MakeMaker 
use ExtUtils::Constant < qw(WriteConstants)
use Config 

# OS2 is a special case, so check for it now.
my $OS2 = "-DOS2" if (config_value: 'osname') eq 'os2' 

my $LIB = "-ldb" 
# so is win32
if ( $^OS_NAME eq 'MSWin32' )
    $LIB = (config_value: 'cc') =~ m/gcc/ ?? "-ldb" !! "-llibdb"

WriteMakefile: 
    NAME                => 'DB_File'
    LIBS                => (@: "-L/usr/local/lib $LIB")
    #INC                => '-I/usr/local/include',
    VERSION_FROM        => 'DB_File.pm'
    OBJECT              => 'version$(OBJ_EXT) DB_File$(OBJ_EXT)'
    XSPROTOARG  => '-noprototypes'
    DEFINE              => $OS2 || ""
    INC         => ($^OS_NAME eq "MacOS" ?? "-i ::::db:include" !! "")
    XS_VERSION      => eval (MM->parse_version: 'DB_File.pm')
    LICENSE  => 'perl'
    ABSTRACT_FROM => 'DB_File.pm'
    AUTHOR       => 'Paul Marquess <pmqs@cpan.org>'

    'depend'    => (%: 'version$(OBJ_EXT)' => 'version.c')
    'clean'             => (%: FILES => 'constants.h constants.xs')
    

my @names = qw(
        BTREEMAGIC
        BTREEVERSION
        DB_LOCK
        DB_SHMEM
        DB_TXN
        HASHMAGIC
        HASHVERSION
        MAX_PAGE_NUMBER
        MAX_PAGE_OFFSET
        MAX_REC_NUMBER
        RET_ERROR
        RET_SPECIAL
        RET_SUCCESS
        R_CURSOR
        R_DUP
        R_FIRST
        R_FIXEDLEN
        R_IAFTER
        R_IBEFORE
        R_LAST
        R_NEXT
        R_NOKEY
        R_NOOVERWRITE
        R_PREV
        R_RECNOSYNC
        R_SETCURSOR
        R_SNAPSHOT
        __R_UNUSED
	)

# Check the constants above all appear in @EXPORT in DB_File.pm
my %names = %+: map: { %: $_, 1}, @names 
open: my $f, "<", "DB_File.pm" or die: "Cannot open DB_File.pm: $^OS_ERROR\n"
while ( ~< $f)
    last if m/^\s*\@EXPORT\s+=\s+ qw\(/x 


while ( ~< $f)
    last if m/^\s*\)/ 
    m/(\S+)/ 
    delete %names{$1} if defined $1 

close $f 

if ( %names )
    my $missing = join: "\n\t", (sort: keys %names) 
    die: "The following names are missing from \@EXPORT in DB_File.pm\n" .
             "\t$missing\n" 



WriteConstants:  NAME => 'DB_File'
                 NAMES => \@names
                 C_FILE  => 'constants.h'
                 XS_FILE  => 'constants.xs'
                 PROXYSUBS => 1
                
