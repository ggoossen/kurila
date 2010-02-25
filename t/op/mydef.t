#!./perl

print: $^STDOUT, "1..65\n"

my $test = 0
sub ok($ok, $name)
    ++$test
    print: $^STDOUT, $ok ?? "ok $test - $name\n" !! "not ok $test - $name\n"


$_ = 'global'
ok:  $_ eq 'global', '$_ initial value' 
s/oba/abo/
ok:  $_ eq 'glabol', 's/// on global $_' 

do
    my $_ = 'local'
    ok:  $_ eq 'local', 'my $_ initial value' 
    s/oca/aco/
    ok:  $_ eq 'lacol', 's/// on my $_' 
    m/(..)/
    ok:  $1 eq 'la', '// on my $_' 
    do
        my $_ = 'nested'
        ok:  $_ eq 'nested', 'my $_ nested' 
        chop
        ok:  $_ eq 'neste', 'chop on my $_' 
    
    do
        our $_
        ok:  $_ eq 'glabol', 'gains access to our global $_' 
    
    ok:  $_ eq 'lacol', 'my $_ restored' 

ok:  $_ eq 'glabol', 'global $_ restored' 
s/abo/oba/
ok:  $_ eq 'global', 's/// on global $_ again' 
do
    my $_ = 11
    our $_ = 22
    ok:  $_ eq 22, 'our $_ is seen explicitly' 
    chop
    ok:  $_ eq 2, '...default chop chops our $_' 
    m/(.)/
    ok:  $1 eq 2, '...default match sees our $_' 


$_ = "global"
do
    my $_ = 'local'
    for my $_ ((@: "foo"))
        ok:  $_ eq "foo", 'for my $_' 
        m/(.)/
        ok:  $1 eq "f", '...m// in for my $_' 
        ok:  our $_ eq 'global', '...our $_ inside for my $_' 
    
    ok:  $_ eq 'local', '...my $_ restored outside for my $_' 
    ok:  our $_ eq 'global', '...our $_ restored outside for my $_' 

do
    my $_ = 'local'
    for ((@: "implicit foo")) # implicit "my $_"
        ok:  $_ eq "implicit foo", 'for implicit my $_' 
        m/(.)/
        ok:  $1 eq "i", '...m// in for implicity my $_' 
        ok:  our $_ eq 'global', '...our $_ inside for implicit my $_' 
    
    ok:  $_ eq 'local', '...my $_ restored outside for implicit my $_' 
    ok:  our $_ eq 'global', '...our $_ restored outside for implicit my $_' 

do
    my $_ = 'local'
    for ((@:  'postfix foo'))
        ok:  $_ eq "postfix foo", 'postfix for' 
    ok:  $_ eq 'local', '...my $_ restored outside postfix for' 
    ok:  our $_ eq 'global', '...our $_ restored outside postfix for' 

do
    for our $_ ((@: "bar"))
        ok:  $_ eq "bar", 'for our $_' 
        m/(.)/
        ok:  $1 eq "b", '...m// in for our $_' 
    
    ok:  $_ eq 'global', '...our $_ restored outside for our $_' 


do
    my $buf = ''
    sub tmap1 { m/(.)/; $buf .= $1 } # uses our $_
    my $_ = 'x'
    sub tmap2 { m/(.)/; $buf .= $1 } # uses my $_
    map: {
             (tmap1: );
             (tmap2: );
             (ok:  m/^[67]\z/, 'local lexical $_ is seen in map' );
             do { ok:  our $_ eq 'global', 'our $_ still visible' ; };
             (ok:  $_ == 6 || $_ == 7, 'local lexical $_ is still seen in map' );
             do { my $_ ; ok:  !defined, 'nested my $_ is undefined' ; };
             }, @:  6, 7
    ok:  $buf eq 'gxgx', q/...map doesn't modify outer lexical $_/ 
    ok:  $_ eq 'x', '...my $_ restored outside map' 
    ok:  our $_ eq 'global', '...our $_ restored outside map' 
    map: { my $_; (ok:  !defined, 'redeclaring $_ in map block undefs it' ); }, @:  1

do { map: { my $_; (ok:  !defined, 'declaring $_ in map block undefs it' ); }, (@:  1); }
do
    sub tmap3 () { return $_ };
    my $_ = 'local'
    sub tmap4 () { return $_ };
    my $x = join: '-', map: { $_.(tmap3: ).(tmap4: )}, 1 .. 2
    ok:  $x eq '1globallocal-2globallocal', 'map without {}' 

do
    my $buf = ''
    sub tgrep1 { m/(.)/; $buf .= $1 }
    my $_ = 'y'
    sub tgrep2 { m/(.)/; $buf .= $1 }
    grep: {
              (tgrep1: );
              (tgrep2: );
              (ok:  m/^[89]\z/, 'local lexical $_ is seen in grep' );
              do { ok:  our $_ eq 'global', 'our $_ still visible' ; };
              (ok:  $_ == 8 || $_ == 9, 'local lexical $_ is still seen in grep' );
              }, @:  8, 9
    ok:  $buf eq 'gygy', q/...grep doesn't modify outer lexical $_/ 
    ok:  $_ eq 'y', '...my $_ restored outside grep' 
    ok:  our $_ eq 'global', '...our $_ restored outside grep' 

do
    sub tgrep3 () { return $_ };
    my $_ = 'local'
    sub tgrep4 () { return $_ };
    my $x = join: '-', grep: { $_=$_.(tgrep3: ).(tgrep4: )}, 1 .. 2
    ok:  $x eq '1globallocal-2globallocal', 'grep without {} with side-effect # TODO' 
    ok:  $_ eq 'local', '...but without extraneous side-effects' 

do
    my $s = "toto"
    my $_ = "titi"
    $s =~ m/to(?{ ok( $_ eq 'toto', 'my $_ in code-match # TODO' ) })to/
        or ok:  0, "\$s=$s should match!" 
    ok:  our $_ eq 'global', '...our $_ restored outside code-match' 


do
    package notmain
    our $_ = 'notmain'
    main::ok:  $::_ eq 'notmain', 'our $_ forced into main::' 
    m/(.*)/
    main::ok:  $1 eq 'notmain', '...m// defaults to our $_ in main::' 


my $file = 'dolbar1.tmp'
END { (unlink: $file); }
do
    open: my $_, '>', $file or die: "Can't open $file: $^OS_ERROR"
    print: $_, "hello\n"
    close $_
    ok:  -s $file, 'writing to filehandle $_ works' 

do
    open: my $_, "<", $file or die: "Can't open $file: $^OS_ERROR"
    my $x = ~< $_
    ok:  $x eq "hello\n", 'reading from <$_> works' 
    close $_


do
    $fqdb::_ = 'fqdb'
    ok:  $fqdb::_ eq 'fqdb', 'fully qualified $_ is not in main' 
    ok:  eval q/$fqdb::_/ eq 'fqdb', 'fully qualified, evaled $_ is not in main' 
    package fqdb;
    main::ok:  $_ ne 'fqdb', 'unqualified $_ is in main' 
    main::ok:  q/$_/ ne 'fqdb', 'unqualified, evaled $_ is in main' 

