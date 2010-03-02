
use Test::More  'no_plan'

my $Class   = 'Module::Load::Conditional'
my $Meth    = '_parse_version'
my $Verbose = (nelems @ARGV) ?? 1 !! 0

use_ok:  $Class 

### versions that should parse
do {   for my $str (  __PACKAGE__->_succeed )
        my $res = $Class->?$Meth:  $str, $Verbose 
        ok:  defined $res,       "String '$str' identified as version string" 

        is:  ($res->vcmp: 0), 1,              "   Version is '$($res->stringify)'" 
    
}

### version that should fail
do {   for my $str (  __PACKAGE__->_fail )
        my $res = $Class->?$Meth:  $str, $Verbose 
        ok:  ! defined $res,     "String '$str' is not a version string" 
    
}


################################
###
### VERSION declarations to test
###
################################

sub _succeed
    return grep: { m/\S/ }, map: { s/^\s*//; $_ }, split: "\n", q[
        our $VERSION = 1;
        *VERSION = \'1.01';
        use version; our $VERSION = qv('0.0.2');
        use version; our $VERSION = qv('3.0.14');
        (our $VERSION) = '$Revision: 2.03 $' =~ m/\s(\d+\.\d+)\s/; 
        ( our $VERSION ) = sprintf '%d.%02d', q$Revision: 1.23 $ =~ m/ (\d+) \. (\d+) /gx;
        ($GD::Graph::area::VERSION) = '$Revision: 1.16.2.3 $' =~ m/\s([\d.]+)/;
        ($GD::Graph::axestype::VERSION) = '$Revision: 1.44.2.14 $' =~ m/\s([\d.]+)/;
        ($GD::Graph::colour::VERSION) = '$Revision: 1.10 $' =~ m/\s([\d.]+)/;
        ($GD::Graph::pie::VERSION) = '$Revision: 1.20.2.4 $' =~ m/\s([\d.]+)/;
        ($GD::Text::Align::VERSION) = '$Revision: 1.18 $' =~ m/\s([\d.]+)/;
        our $VERSION = qv('0.0.1');
        use version; our $VERSION = qv('0.0.3');
        our $VERSION = do { my @r = @: ( my $v = q<Version value="0.20.1"> ) =~ m/\d+/g ; sprintf '%d.%02d', @r[0], int( @r[1] / 10 ) };
        (our $VERSION) = sprintf '%i.%03i', < split(m/\./, (@: '$Revision: 2.0 $' =~ m/Revision: (\S+)\s/)[0]); # $Date: 2005/11/16 02:16:00 $
        (our  $VERSION = q($Id: Tidy.pm,v 1.56 2006/07/19 23:13:33 perltidy Exp $) ) =~ s/^.*\s+(\d+)\/(\d+)\/(\d+).*$/$1$2$3/; # all one line for MakeMaker
        (our $VERSION) = q $Revision: 2.120 $ =~ m/([\d.]+)/;
        (our $VERSION) = q$Revision: 1.00 $ =~ m/([\d.]+)/;
        our $VERSION = "3.0.8";
        our $VERSION = '1.0.5';
    ]


sub _fail
    return grep: { m/\S/ }, map: { s/^\s*//; $_ }, split: "\n", q[
        our ($VERSION, %ERROR, $ERROR, $Warn, $Die);
        sub version { $GD::Graph::colour::VERSION }
        my $VERS = qr{ $HWS VERSION $HWS \n }xms;
        diag( "Testing $main_module \$${main_module}::VERSION" );
        our ( $VERSION, $v, $_VERSION );
        my $seen = { q{::} => { 'VERSION' => 1 } }; # avoid multiple scans
        eval "$module->VERSION"
        'VERSION' => '1.030' # Variable and Value
        'VERSION' => '2.121_020'
        'VERSION' => '0.050', # Standard variable $VERSION
        our ( $VERSION, $seq, @FontDirs );
        $VERSION
        # *VERSION = \'1.01';
        # ( $VERSION ) = '$Revision: 1.56 $ ' =~ m/\$Revision:\s+([^\s]+)/;
        #$VERSION = sprintf('%d.%s', map {s/_//g; $_} q$Name: $ =~ m/-(\d+)_([\d_]+)/);
        #$VERSION = sprintf('%d.%s', map {s/_//g; $_} q$Name: $ =~ m/-(\d+)_([\d_]+)/);
    ]

