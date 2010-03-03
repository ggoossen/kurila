#!./perl

BEGIN 
    require './test.pl'

$^OUTPUT_AUTOFLUSH  = 1
use warnings
use Config
my $Is_VMS = $^OS_NAME eq 'VMS'
my $Is_MacOS = $^OS_NAME eq 'MacOS'

our ($f)

plan: tests => 97

my $Perl = (which_perl: )

do
    unlink: "afile" if -f "afile"

    $^OS_ERROR = 0  # the -f above will set $! if 'afile' doesn't exist.
    ok:  (open: my $f, "+>","afile"),  'open(my $f, "+>...")' 

    binmode: $f
    ok:  -f "afile",             '       its a file'
    ok:  ((print: $f, "SomeData\n")),  '       we can print to it'
    is:  (tell: $f), 9,            '       tell()' 
    ok:  (seek: $f,0,0),           '       seek set' 

    $b = ~< $f
    is:  $b, "SomeData\n",       '       readline' 
    ok:  -f $f,                  '       still a file' 

    ok:  (close: $f),              '       close()' 
    ok:  (unlink: "afile"),        '       unlink()' 


do
    ok:  (open: my $f,'>', 'afile'),       "open(my \$f, '>', 'afile')" 
    ok:  ((print: $f, "a row\n")),           '       print'
    ok:  (close: $f),                      '       close' 
    ok:  -s 'afile' +< 10,                '       -s' 


do
    ok:  (open: my $f,'>>', 'afile'),      "open(my \$f, '>>', 'afile')" 
    ok:  ((print: $f, "a row\n")),           '       print' 
    ok:  (close: $f),                      '       close' 
    ok:  -s 'afile' +> 10,                '       -s'    


do
    ok:  (open: my $f, '<', 'afile'),      "open(my \$f, '<', 'afile')" 
    my @rows = @:  ~< $f 
    is:  scalar nelems @rows, 2,                '       readline, list context' 
    is:  @rows[0], "a row\n",            '       first line read' 
    is:  @rows[1], "a row\n",            '       second line' 
    ok:  (close: $f),                      '       close' 


do
    ok:  -s 'afile' +< 20,                '-s' 

    ok:  (open: my $f, '+<', 'afile'),     'open +<' 
    my @rows = @:  ~< $f 
    is:  scalar nelems @rows, 2,                '       readline, list context' 
    ok:  (seek: $f, 0, 1),                 '       seek cur' 
    ok:  ((print: $f, "yet another row\n")), '       print' 
    ok:  (close: $f),                      '       close' 
    ok:  -s 'afile' +> 20,                '       -s' 

    unlink: "afile"


:SKIP do
    skip: "open -| busted and noisy on VMS", 3 if $Is_VMS

    ok:  (open: my $f, '-|', <<EOC),     'open -|' 
    $Perl -e "print: \\\$^STDOUT, qq(a row\\n); print:  \\\$^STDOUT,qq(another row\\n)"
EOC

    my @rows = @:  ~< $f 
    is:  scalar nelems @rows, 2,                '       readline, list context' 
    ok:  (close: $f),                      '       close' 


:SKIP do
    skip: "Output for |- doesn't go to shell on MacOS", 5 if $Is_MacOS

    ok:  (open: my $f, '|-', $Perl . <<'EOC'),     'open |-' 
    -e 'while (my $_ = ~< $^STDIN) { s/^not //; print: $^STDOUT, $_; }'
EOC

    my @rows = @:  ~< $f 
    my $test = (curr_test: )
    print: $f, "not ok $test - piped in\n"
    (next_test: )

    $test = (curr_test: )
    print: $f, "not ok $test - piped in\n"
    (next_test: )
    ok:  (close: $f),                      '       close' 
    sleep 1
    pass: 'flushing'



ok:  !try { (open: my $f, '<&', 'afile'); 1; },    '<& on a non-filehandle' 
like:  $^EVAL_ERROR->message, qr/Bad filehandle:\s+afile/,          '       right error' 


# local $file tests
do
    unlink: "afile" if -f "afile"

    ok:  (open: local $f, "+>","afile"),       'open local $f, "+>", ...' 
    binmode: $f

    ok:  -f "afile",                     '       -f' 
    ok:  ((print: $f, "SomeData\n")),        '       print' 
    is:  (tell: $f), 9,                    '       tell' 
    ok:  (seek: $f,0,0),                   '       seek set' 

    $b = ~< $f
    is:  $b, "SomeData\n",               '       readline' 
    ok:  -f $f,                          '       still a file' 

    ok:  (close: $f),                      '       close' 

    unlink: "afile"


do
    ok:  (open: local $f,'>', 'afile'),    'open local $f, ">", ...' 
    ok:  ((print: $f, "a row\n")),           '       print'
    ok:  (close: $f),                      '       close'
    ok:  -s 'afile' +< 10,                '       -s' 


do
    ok:  (open: local $f,'>>', 'afile'),   'open local $f, ">>", ...' 
    ok:  ((print: $f, "a row\n")),           '       print'
    ok:  (close: $f),                      '       close'
    ok:  -s 'afile' +> 10,                '       -s' 


do
    ok:  (open: local $f, '<', 'afile'),   'open local $f, "<", ...' 
    my @rows = @:  ~< $f 
    is:  scalar nelems @rows, 2,                '       readline list context' 
    ok:  (close: $f),                      '       close' 


ok:  -s 'afile' +< 20,                '       -s' 

do
    ok:  (open: local $f, '+<', 'afile'),  'open local $f, "+<", ...' 
    my @rows = @:  ~< $f 
    is:  scalar nelems @rows, 2,                '       readline list context' 
    ok:  (seek: $f, 0, 1),                 '       seek cur' 
    ok:  ((print: $f, "yet another row\n")), '       print' 
    ok:  (close: $f),                      '       close' 
    ok:  -s 'afile' +> 20,                '       -s' 

    unlink: "afile"


:SKIP do
    skip: "open -| busted and noisy on VMS", 3 if $Is_VMS

    ok:  (open: local $f, '-|', <<EOC),  'open local $f, "-|", ...' 
    $Perl -e "print: \\\$^STDOUT, qq(a row\\n); print: \\\$^STDOUT, qq(another row\\n)"
EOC
    my @rows = @:  ~< $f 

    is:  scalar nelems @rows, 2,                '       readline list context' 
    ok:  (close: $f),                      '       close' 


:SKIP do
    skip: "Output for |- doesn't go to shell on MacOS", 5 if $Is_MacOS

    ok:  (open: local $f, '|-', $Perl . <<'EOC'),  'open local $f, "|-", ...' 
    -e 'while (my $_ = ~< $^STDIN) { s/^not //; print: $^STDOUT, $_; }'
EOC

    my @rows = @:  ~< $f 
    my $test = (curr_test: )
    print: $f, "not ok $test - piping\n"
    (next_test: )

    $test = (curr_test: )
    print: $f, "not ok $test - piping\n"
    (next_test: )
    ok:  (close: $f),                      '       close' 
    sleep 1
    pass: "Flush"



ok:  !try { (open: local $f, '<&', 'afile'); 1 },  'local <& on non-filehandle'
like:  $^EVAL_ERROR->message, qr/Bad filehandle:\s+afile/,          '       right error' 

do
    for (1..2)
        ok:  (open: my $f, "-|", qq{$Perl -e "print: \\\$^STDOUT, 'ok\n'"}), 'open -|'
        is:  scalar ~< $f, "ok\n", '       readline'
        ok:  close $f,            '       close' 
    



# other dupping techniques
do
    ok:  (open: my $stdout, ">&", $^STDOUT),       'dup $^STDOUT into lexical fh'
    ok:  (open: $^STDOUT,     ">&", $stdout),        'restore dupped STDOUT from lexical fh'

    # used to try to open a file [perl #17830]
    ok:  (open: my $stdin,  "<&", fileno $^STDIN),   'dup fileno(STDIN) into lexical fh' or _diag: $^OS_ERROR


:SKIP do
    skip: "This perl uses perlio", 1 if config_value: "useperlio"
    skip: "miniperl cannot be relied on to load \%Errno"
        if env::var: 'PERL_CORE_MINITEST'
    require Errno
    # Force the reference to %! to be run time by writing ! as {"!"}
    skip: "This system doesn't understand EINVAL", 1
        unless exists &Errno::EINVAL

    no warnings 'io'
    ok: !(open: my $f,'>',\my $s) && $^OS_ERROR ==( Errno::EINVAL: ), 'open(reference) raises EINVAL'


do
    ok:  !try { (open: my $f, "BAR", "QUUX") },       'Unknown open() mode' 
    like:  $^EVAL_ERROR->message, qr/\QUnknown open() mode 'BAR'/, '       right error' 


do
    local $^WARN_HOOK = sub (@< @_) { $^EVAL_ERROR = shift }

    sub gimme
        my $tmphandle = shift
        my $line = scalar ~< $tmphandle
        warn: "gimme"
        return $line
    


:SKIP do
    skip: "These tests use perlio", 5 unless config_value: "useperlio"
    my $w
    use warnings 'layer';
    local $^WARN_HOOK = sub (@< @_) { $w = shift->message }

    try { (open: my $f, ">>>", "afile") }
    like: $w, qr/Invalid separator character '>' in PerlIO layer spec/
          "bad open (>>>) warning"
    like: $^EVAL_ERROR->message, qr/Unknown open\(\) mode '>>>'/
          "bad open (>>>) failure"

    try { (open: my $f, ">:u", "afile" ) }
    ok:  ! $^EVAL_ERROR 
    like: $w, qr/Unknown PerlIO layer "u"/
          'bad layer ">:u" warning'
    try { (open: my $f, "<:u", "afile" ) }
    ok:  ! $^EVAL_ERROR 
    like: $w, qr/Unknown PerlIO layer "u"/
          'bad layer "<:u" warning'
    try { (open: my $f, ":c", "afile" ) }
    like: $^EVAL_ERROR->message, qr/Unknown open\(\) mode ':c'/
          'bad layer ":c" failure'


# [perl #28986] "open m" crashes Perl

fresh_perl_like: 'open m', qr/^Search pattern not terminated at/
                 \(%:  stderr => 1 ), 'open m test'

fresh_perl_is: 
    'sub f { open(my $fh, "<", "xxx"); $fh = "f"; } f; f;print: $^STDOUT, "ok"'
    'ok', \(%:  stderr => 1 )
    '#29102: Crash on assignment to lexical filehandle'

# [perl #31767] Using $1 as a filehandle via open $1, "file" doesn't raise
# an exception

try { (open: $99, "<", "foo") }
like: $^EVAL_ERROR->message, qr/Modification of a read-only value attempted/, "readonly fh"
