#!perl -w

our $file;

$file = "storable-testfile.$^PID";
die "Temporary file '$file' already exists" if -e $file;

END { while (-f $file) {unlink $file or die "Can't unlink '$file': $^OS_ERROR" }}

use Storable < qw (store retrieve freeze thaw nstore nfreeze);

sub slurp {
  my $file = shift;
  local (*FH, $^INPUT_RECORD_SEPARATOR);
  open FH, "<", "$file" or die "Can't open '$file': $^OS_ERROR";
  binmode FH;
  my $contents = ~< *FH;
  die "Can't read $file: $^OS_ERROR" unless defined $contents;
  return $contents;
}

sub store_and_retrieve {
  my $data = shift;
  unlink $file or die "Can't unlink '$file': $^OS_ERROR";
  open FH, ">", "$file" or die "Can't open '$file': $^OS_ERROR";
  binmode FH;
  print FH $data or die "Can't print to '$file': $^OS_ERROR";
  close FH or die "Can't close '$file': $^OS_ERROR";

  return  try {retrieve $file};
}

sub freeze_and_thaw {
  my $data = shift;
  return try {thaw $data};
}

$file;
