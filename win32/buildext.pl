=head1 NAME

buildext.pl - build extensions

=head1 SYNOPSIS

    buildext.pl make [-make_opts] dep directory [target]

E.g.

    buildext.pl nmake -nologo perldll.def ..\ext

    buildext.pl nmake -nologo perldll.def ..\ext clean

    buildext.pl dmake perldll.def ..\ext

    buildext.pl dmake perldll.def ..\ext clean

=cut

use File::Basename;
use Cwd;
use FindExt;
my $here = getcwd();
my $perl = $^X;
$here =~ s,/,\\,g;
if ($perl =~ m#^\.\.#)
 {
  $perl = "$here\\$perl";
 }
(my $topdir = $perl) =~ s/\\[^\\]+$//;
# miniperl needs to find perlglob and pl2bat
$ENV{PATH} = "$topdir;$topdir\\win32\\bin;$ENV{PATH}";
#print "PATH=$ENV{PATH}\n";
my $pl2bat = "$topdir\\win32\\bin\\pl2bat";
unless (-f "$pl2bat.bat") {
    my @args = ($perl, ("$pl2bat.pl") x 2);
    print "@args\n";
    system(@args);
}
my $make = shift;
$make .= " ".shift while $ARGV[0]=~/^-/;
my $dep  = shift;
my $dmod = -M $dep;
my $dir  = shift;
chdir($dir) || die "Cannot cd to $dir\n";
my $targ  = shift;
(my $ext = getcwd()) =~ s,/,\\,g;
FindExt::scan_ext($ext);

my @ext = FindExt::extensions();

foreach my $dir (sort @ext)
 {
  if (chdir("$ext\\$dir"))
   {
    my $mmod = -M 'Makefile';
    if (!(-f 'Makefile') || $mmod > $dmod)
     {
      print "\nRunning Makefile.PL in $dir\n";
      my @perl = ($perl, "-I$here\\..\\lib", 'Makefile.PL',
                  'INSTALLDIRS=perl', 'PERL_CORE=1');
      print join(' ', @perl), "\n";
      my $code = system(@perl);
      warn "$code from $dir's Makefile.PL" if $code;
      $mmod = -M 'Makefile';
      if ($mmod > $dmod)
       {
        warn "Makefile $mmod > $dmod ($dep)\n";
       }
     }  
    if ($targ)
     {
      print "Making $targ in $dir\n$make $targ\n";
      system("$make $targ");
     }
    else
     {
      print "Making $dir\n$make\n";
      system($make);
     }
    chdir($here) || die "Cannot cd to $here:$!";
   }
  else
   {
    warn "Cannot cd to $ext\\$dir:$!";
   }
 }

