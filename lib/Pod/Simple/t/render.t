
use utf8;
use charnames ':full';

use Test::More;
plan tests => 26;
use Pod::Simple::TextContent;
use Pod::Simple::Text;

BEGIN {
  *mytime = defined(&Win32::GetTickCount)
    ?? sub () {Win32::GetTickCount() / 1000}
    !! sub () {time()}
}

$Pod::Simple::Text::FREAKYMODE = 1;

chdir 't' unless env::var('PERL_CORE');

sub source_path {
    my $file = shift;
    if (env::var('PERL_CORE')) {
        require File::Spec;
        my $updir = File::Spec->updir;
        my $dir = File::Spec->catdir ($updir, 'lib', 'Pod', 'Simple', 't');
        return File::Spec->catfile ($dir, $file);
    } else {
        return $file;
    }
}

my $outfile = '10000';

foreach my $file (@(
  "junk1.pod",
  "junk2.pod",
  "perlcyg.pod",
  "perlfaq.pod",
  "perlvar.pod",)
) {

  unless(-e source_path($file)) {
    ok 0;
    print "# But $file doesn't exist!!\n";
    exit 1;
  }

  my @out;
  my $precooked = source_path($file);
  $precooked =~ s<\.pod><o.txt>s;
  unless(-e $precooked) {
    ok 0;
    print "# But $precooked doesn't exist!!\n";
    exit 1;
  }
  
  print "#\n#\n#\n###################\n# $file\n";
  foreach my $class (@('Pod::Simple::TextContent', 'Pod::Simple::Text')) {
    my $p = $class->new;
    push @out, '';
    $p->output_string(\@out[-1]);
    my $t = mytime();
    $p->parse_file( source_path($file));
    printf "# \%s \%s \%sb, \%.03fs\n",
     ref($p), source_path($file), length(@out[-1]), mytime() - $t ;
    ok 1;
  }

  print "# Reading $precooked...\n";
  open(my $in, "<", $precooked) or die "Can't read-open $precooked: $^OS_ERROR";
  do {
    local $^INPUT_RECORD_SEPARATOR;
    push @out, ~< $in;
  };
  close($in);
  print "#   ", length(@out[-1]), " bytes pulled in.\n";
  
  @out = map {
               join '', @( pack("U*", unpack("C*", $_))) # latin1 decode.
             } @out; 

  for ( @out) { s/\s+/ /g; s/^\s+//s; s/\s+$//s; }

  my $faily = 0;
  print "#\n#Now comparing 1 and 2...\n";
  $faily += compare2(@out[0], @out[1]);
  print "#\n#Now comparing 2 and 3...\n";
  $faily += compare2(@out[1], @out[2]);
  print "#\n#Now comparing 1 and 3...\n";
  $faily += compare2(@out[0], @out[2]);

  if($faily) {
    ++$outfile;
    
    my @outnames = map $outfile . $_, qw(0 1);
    open(my $out2, ">", "@outnames[0].~out.txt") || die "Can't write-open @outnames[0].txt: $^OS_ERROR";

    foreach my $out ( @out) { push @outnames, @outnames[-1];  ++@outnames[-1] };
    pop @outnames;
    printf "# Writing to \%s.txt .. \%s.txt\n", @outnames[0], @outnames[-1];
    shift @outnames;
    
    binmode($out2);
    foreach my $out ( @out) {
      my $outname = shift @outnames;
      open(my $out_fh, ">", "$outname.txt") || die "Can't write-open $outname.txt: $^OS_ERROR";
      binmode($out_fh);
      print $out_fh  $out, "\n";
      print $out2 $out, "\n";
      close($out_fh);
    }
    close($out2);
  }
}

print "# Wrapping up... one for the road...\n";
ok 1;
print "# --- Done with ", __FILE__, " --- \n";
exit;


sub compare2 {
  my @out = @_;
  if(@out[0] eq @out[1]) {
    ok 1;
    return 0;
  } elsif( do{
    for (@(@out[0], @out[1])) { s/[ ]//g; };
    @out[0] eq @out[1];
  }){
    print "# Differ only in whitespace.\n";
    ok 1;
    return 0;
  } else {
    #ok $out[0], $out[1];
    
    my $x = @out[0] ^^^ @out[1];
    $x =~ m/^(\x00*)/s or die;
    my $at = length($1);
    print "# Difference at byte $at...\n";
    if($at +> 10) {
      $at -= 5;
    }
    do {
      print "# ", substr(@out[0],$at,20), "\n";
      print "# ", substr(@out[1],$at,20), "\n";
      print "#      ^...";
    };
    
    
    
    ok 0;
    printf "# Unequal lengths \%s and \%s\n", length(@out[0]), length(@out[1]);
    return 1;
  }
}


__END__

