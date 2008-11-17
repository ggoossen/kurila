=comment

Synchronize filename cases for extensions.

This script could be used to perform following renaming:
if there exist file, for example, "FiLeNaME.c" and
filename.obj then it renames "filename.obj" to "FiLeNaME.obj".
There is a problem when some compilers (e.g.Borland) generate
such .obj files and then "make" process will not treat them
as dependant and already maked files.

This script takes two arguments - first and second extensions to
synchronize filename cases with.

There may be specified following options:
  --verbose    <== say everything what is going on
  --recurse    <== recurse subdirectories
  --dummy      <== do not perform actual renaming
  --say-subdir
Every such option can be specified with an optional "no" prefix to negate it.

Typically, it is invoked as:
  perl sync_ext.pl c obj --verbose

=cut


my @($ext1, $ext2) =  map {quotemeta} grep {!m/^--/} @ARGV;
my %opts = %(
  #defaults
    'verbose' => 0,
    'recurse' => 1,
    'dummy' => 0,
    'say-subdir' => 0,
  #options itself
    (< map {m/^--([\-_\w]+)=(.*)$/} @ARGV),                            # --opt=smth
    (< map {m/^no-?(.*)$/i??($1=>0)!!($_=>1)} map {m/^--([\-_\w]+)$/} @ARGV),  # --opt --no-opt --noopt
  );

my $sp = '';
sub xx {
  opendir DIR, '.';
  my @t = @( readdir DIR );
  my @f = map {m/^(.*)\.$ext1$/i} @t;
  my %f = %( < map {lc($_)=>$_} map {m/^(.*)\.$ext2$/i} @t );
  for ( @f) {
    my $lc = lc($_);
    if (exists %f{$lc} and %f{?$lc} ne $_) {
      print STDERR "$sp%f{?$lc}.$ext2 <==> $_.$ext1\n" if %opts{?verbose};
      if (%opts{?dummy}) {
        print STDERR "ren %f{?$lc}.$ext2 $_.$ext2\n";
      }
      else {
        system "ren %f{?$lc}.$ext2 $_.$ext2";
      }
    }
  }
  if (%opts{?recurse}) {
    for ( grep {-d&&!m/^\.\.?$/} @t) {
      print STDERR "$sp\\$_\n" if %opts{?'say-subdir'};
      $sp .= ' ';
      chdir $_ or die;
      xx();
      chdir ".." or die;
      chop $sp;
    }
  }
}

xx();
