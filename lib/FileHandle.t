#!./perl

use TestInit;
use Config;

BEGIN {
    if ($^OS_NAME eq 'mpeix') {
	print "1..0 # Skip: broken on MPE/iX\n";
	exit 0;
    }
}

use FileHandle;


(\*STDOUT)->autoflush( 1);

my $mystdout = FileHandle->new_from_fd( 1,"w");
$^OUTPUT_AUTOFLUSH = 1;
 $mystdout->autoflush();
print "1..12\n";

print $mystdout "ok ".fileno($mystdout)."\n";

my $fh = (FileHandle->new( "./TEST", O_RDONLY)
       or FileHandle->new( "TEST", O_RDONLY))
  and print "ok 2\n";


my $buffer = ~< $fh;
print $buffer eq "#!./perl\n" ?? "ok 3\n" !! "not ok 3\n";
 $fh->

ungetc( ord 'A');
CORE::read($fh, my $buf,1);
print $buf eq 'A' ?? "ok 4\n" !! "not ok 4\n";

close $fh;

$fh = FileHandle->new();

print "not " unless ($fh->open("TEST", "<") && ~< $fh eq $buffer);
print "ok 5\n";

$fh->seek(0,0);
print "#possible mixed CRLF/LF in t/TEST\nnot " unless ( ~< $fh eq $buffer);
print "ok 6\n";

$fh->seek(0,2);
my $line = ~< $fh;
print "not " if (defined($line) || !$fh->eof);
print "ok 7\n";

print "not " unless ($fh->open("TEST","r") && !$fh->tell && $fh->close);
print "ok 8\n";

(\*STDOUT)->autoflush( 0);

print "not " if ($^OUTPUT_AUTOFLUSH);
print "ok 9\n";

(\*STDOUT)->autoflush( 1);

print "not " unless ($^OUTPUT_AUTOFLUSH);
print "ok 10\n";

if ($^OS_NAME eq 'dos')
{
    printf("ok \%d\n",11);
    exit(0);
}

my @($rd,$wr) =  FileHandle::pipe;

if ($^OS_NAME eq 'VMS' || $^OS_NAME eq 'os2' || $^OS_NAME eq 'amigaos' || $^OS_NAME eq 'MSWin32' || $^OS_NAME eq 'NetWare' ||
    config_value('d_fork') ne 'define') {
  $wr->autoflush;
  $wr->printf("ok \%d\n",11);
  print < $rd->getline;
}
else {
  if (fork) {
   $wr->close;
   print $rd->getline;
  }
  else {
   $rd->close;
   $wr->printf("ok \%d\n",11);
   exit(0);
  }
}

print FileHandle->new('','r') ?? "not ok 12\n" !! "ok 12\n";
