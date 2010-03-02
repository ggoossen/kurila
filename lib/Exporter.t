#!perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @:  '../lib'


# Can't use Test::Simple/More, they depend on Exporter.
my $test
sub ok($ok, $name)

    # You have to do it this way or VMS will get confused.
    printf: $^STDOUT, "\%sok \%d\%s\n", ($ok ?? '' !! 'not '), $test
            (defined $name ?? " - $name" !! '')

    printf: $^STDOUT, "# Failed test at line \%d\n", (@: caller)[2] unless $ok

    $test++
    return $ok


BEGIN 
    $test = 1
    print: $^STDOUT, "1..25\n"
    require Exporter
    ok:  1, 'Exporter compiled' 

our @Exporter_Methods

BEGIN 
    # Methods which Exporter says it implements.
    @Exporter_Methods = qw(import
                           export_to_level
                           require_version
                           export_fail
                          )

do
    package Testing
    require Exporter
    our @ISA = qw(Exporter)

    # Make sure Testing can do everything its supposed to.
    foreach my $meth ( @main::Exporter_Methods)
        main::ok:  (Testing->can: $meth), "subclass can $meth()" 
    

    our %EXPORT_TAGS = %:
        This => qw(stuff %left)
        That => qw(Above the @wailing)
        tray => qw(Fasten $seatbelt)
        
    our @EXPORT    = qw(lifejacket is)
    our @EXPORT_OK = qw(under &your $seat)
    our $VERSION = '1.05'

    main::ok:  (Testing->require_version: 1.05),   'require_version()' 
    try { (Testing->require_version: 1.11); 1 }
    main::ok:  $^EVAL_ERROR,                               'require_version() fail' 
    main::ok:  (Testing->require_version: 0),      'require_version(0)' 

    sub lifejacket  { 'lifejacket'  }
    sub stuff       { 'stuff'       }
    sub Above       { 'Above'       }
    sub the         { 'the'         }
    sub Fasten      { 'Fasten'      }
    sub your        { 'your'        }
    sub under       { 'under'       }
    our ($seatbelt, $seat, @wailing, %left)
    $seatbelt = 'seatbelt'
    $seat     = 'seat'
    @wailing = qw(AHHHHHH)
    %left = %:  left => "right" 

    sub Is { 'Is' };
    BEGIN {*is = \&Is};

    (Exporter::export_ok_tags: )

    my %tags     = %+: map: { %: $_ => 1 }, @+: values %EXPORT_TAGS
    my %exportok = %+: map: { %: $_ => 1 }, @EXPORT_OK
    my $ok = 1
    foreach my $tag (keys %tags)
        $ok = exists %exportok{$tag}
    
    main::ok:  $ok, 'export_ok_tags()' 


do
    package Foo
    Testing->import

    main::ok:  exists &lifejacket,      'simple import' 

    my $got = try {(lifejacket:  < @_ )}
    main::ok :  $^EVAL_ERROR eq "", 'check we can call the imported subroutine'
        or print: $^STDERR, "# \$\@ is $^EVAL_ERROR\n"
    main::ok :  $got eq 'lifejacket', 'and that it gave the correct result'
        or print: $^STDERR, "# expected 'lifejacket', got " .
                      (defined $got ?? "'$got'" !! "undef") . "\n"

    # The string eval is important. It stops $Foo::{is} existing when
    # Testing->import is called.
    main::ok:  eval "defined &is"
               "Import a subroutine where exporter must create the typeglob" 
    $got = eval "&is <: "
    main::ok :  ! $^EVAL_ERROR, 'check we can call the imported autoloaded subroutine'
        or (chomp: $^EVAL_ERROR), print: $^STDERR, "# \$\@ is $^EVAL_ERROR\n"
    main::ok :  $got eq 'Is', 'and that it gave the correct result'
        or print: $^STDERR, "# expected 'Is', got " .
                      (defined $got ?? "'$got'" !! "undef") . "\n"


package Bar
my @imports = qw($seatbelt &Above stuff @wailing %left)
Testing->import: < @imports

main::ok:  (!(grep: { eval "!defined $_" }, (map: { m/^\w/ ?? "&$_" !! $_ }, @imports)))
           'import by symbols' 


package Yar
my @tags = qw(:This :tray)
Testing->import: < @tags

main::ok:  (!(grep: { eval "!defined $_" }, (map: { m/^\w/ ?? "&$_" !! $_ },
                                                      @+: %Testing::EXPORT_TAGS{[ (map: { s/^://; $_ },@tags) ]})))
           'import by tags' 


package Arrr
Testing->import:  <qw(!lifejacket)

main::ok:  !exists &lifejacket,     'deny import by !' 


package Mars
Testing->import: '/e/'

main::ok:  (!(grep: { eval "!defined $_" }, (map: { m/^\w/ ?? "&$_" !! $_ },
                                                      (grep: { m/e/ }, (@:  < @Testing::EXPORT, < @Testing::EXPORT_OK)))))
           'import by regex'


package Venus
Testing->import: '!/e/'

main::ok:  (!(grep: { eval "defined $_" }, (map: { m/^\w/ ?? "&$_" !! $_ },
                                                     (grep: { m/e/ }, (@:  < @Testing::EXPORT, < @Testing::EXPORT_OK)))))
           'deny import by regex'
main::ok:  !exists &lifejacket, 'further denial' 


do
    package More::Testing
    our @ISA = qw(Exporter)
    our $VERSION = 0
    try { (More::Testing->require_version: 0); 1 }
    main::ok: !$^EVAL_ERROR,       'require_version(0) and $VERSION = 0'


package Moving::Target
our @ISA = qw(Exporter)
our @EXPORT_OK = qw (foo)

sub foo {"This is foo"};
sub bar {"This is bar"};

package Moving::Target::Test

Moving::Target->import : 'foo'

main::ok : (foo: ) eq "This is foo", "imported foo before EXPORT_OK changed"

push: @Moving::Target::EXPORT_OK, 'bar'

Moving::Target->import : 'bar'

main::ok : (bar: ) eq "This is bar", "imported bar after EXPORT_OK changed"

package The::Import

use Exporter 'import'

main::ok: \&import \== \&Exporter::import, "imported the import routine"

our @EXPORT = qw( wibble )
sub wibble {return "wobble"};

