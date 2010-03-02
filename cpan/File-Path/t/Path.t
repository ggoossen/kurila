# Path.t -- tests for module File::Path


use Test::More tests => 94

BEGIN 
    use_ok: 'File::Path'
    use_ok: 'File::Spec::Functions'


eval "use Test::Output"
my $has_Test_Output = $^EVAL_ERROR ?? 0 !! 1

my $Is_VMS   = $^OS_NAME eq 'VMS'

# first check for stupid permissions second for full, so we clean up
# behind ourselves
for my $perm ((@: 0111,0777))
    my $path = catdir: (curdir: ), "mhx", "bar"
    mkpath: $path
    chmod: $perm, "mhx", $path

    my $oct = sprintf: '0%o', $perm
    ok: -d "mhx", "mkdir parent dir $oct"
    ok: -d $path, "mkdir child dir $oct"

    rmtree: "mhx"
    ok: ! -e "mhx", "mhx does not exist $oct"


# find a place to work
my ($error, $list, $file, $message)
my $tmp_base = catdir: 
    (curdir: )
    (sprintf:  'test-%x-%x-%x', time, $^PID, (rand: 99999) )
    

# invent some names
my @dir = @:
    catdir: $tmp_base, < qw(a b)
    catdir: $tmp_base, < qw(a c)
    catdir: $tmp_base, < qw(z b)
    catdir: $tmp_base, < qw(z c)

# create them
my @created = mkpath: < @dir

is: (scalar: nelems @created), 7, "created list of directories"

# pray for no race conditions blowing them out from under us
@created = mkpath: \(@: $tmp_base)
is: (scalar: nelems @created), 0, "skipped making existing directory"
    or diag: "unexpectedly recreated $((join: ' ',@created))"

@created = mkpath: ''
is: (scalar: nelems @created), 0, "Can't create a directory named ''"

my $dir
my $dir2

:SKIP do
    $dir = catdir: $tmp_base, 'B'
    $dir2 = catdir: $dir, (updir: )
    # IOW: File::Spec->catdir( qw(foo bar), File::Spec->updir ) eq 'foo'
    # rather than foo/bar/..
    skip: "updir() canonicalises path on this platform", 2
        if $dir2 eq $tmp_base
      or $^OS_NAME eq 'cygwin'

    @created = mkpath: $dir2, \(%: mask => 0700)
    is: (scalar: nelems @created), 1, "make directory with trailing parent segment"
    is: @created[0], $dir, "made parent"
;

my $count = rmtree: \(%: error => \$error)
is:  $count, 0, 'rmtree of nothing, count of zero' 
is:  (scalar: nelems $error->@), 0, 'no diagnostic captured' 

@created = mkpath: $tmp_base, 0
is: (scalar: nelems @created), 0, "skipped making existing directories (old style 1)"
    or diag: "unexpectedly recreated $((join: ' ',@created))"

$dir = catdir: $tmp_base,'C'
# mkpath returns unix syntax filespecs on VMS
$dir = (VMS::Filespec::unixify: $dir) if $Is_VMS
@created = mkpath: $tmp_base, $dir
is: (scalar: nelems @created), 1, "created directory (new style 1)"
is: @created[0], $dir, "created directory (new style 1) cross-check"

@created = mkpath: $tmp_base, 0, 0700
is: (scalar: nelems @created), 0, "skipped making existing directories (old style 2)"
    or diag: "unexpectedly recreated $((join: ' ',@created))"

$dir2 = catdir: $tmp_base,'D'
# mkpath returns unix syntax filespecs on VMS
$dir2 = (VMS::Filespec::unixify: $dir2) if $Is_VMS
@created = mkpath: $tmp_base, $dir, $dir2
is: (scalar: nelems @created), 1, "created directory (new style 2)"
is: @created[0], $dir2, "created directory (new style 2) cross-check"

# mkdir foo ./E/../Y
# Y should exist
# existence of E is neither here nor there
$dir = catdir: $tmp_base, 'E', (updir: ), 'Y'
@created =mkpath: $dir
cmp_ok: (scalar: nelems @created), '+>=', 1, "made one or more dirs because of .."
cmp_ok: (scalar: nelems @created), '+<=', 2, "made less than two dirs because of .."
ok:  -d (catdir: $tmp_base, 'Y'), "directory after parent" 

@created = mkpath: (catdir: (curdir: ), $tmp_base)
is: (scalar: nelems @created), 0, "nothing created"
    or diag: < @created

$dir  = catdir: $tmp_base, 'a'
$dir2 = catdir: $tmp_base, 'z'

rmtree:  $dir, $dir2
         \%:
             error     => \$error
             result    => \$list
             keep_root => 1
        
        

is: (scalar: nelems $error->@), 0, "no errors unlinking a and z"
is: (scalar: nelems $list->@),  4, "list contains 4 elements"
    or diag: "$((join: ' ',$list->@))"

ok: -d $dir,  "dir a still exists"
ok: -d $dir2, "dir z still exists"

$dir = catdir: $tmp_base,'F'
# mkpath returns unix syntax filespecs on VMS
$dir = (VMS::Filespec::unixify: $dir) if $Is_VMS

@created = mkpath: $dir, undef, 0770
is: (scalar: nelems @created), 1, "created directory (old style 2 verbose undef)"
is: @created[0], $dir, "created directory (old style 2 verbose undef) cross-check"
is: (rmtree: $dir), 1, "removed directory 2 verbose undef"

@created = mkpath: $dir, undef
is: (scalar: nelems @created), 1, "created directory (old style 2a verbose undef)"
is: @created[0], $dir, "created directory (old style 2a verbose undef) cross-check"
is: (rmtree: $dir), 1, "removed directory 2a verbose undef"

@created = mkpath: $dir, 0, undef
is: (scalar: nelems @created), 1, "created directory (old style 3 mode undef)"
is: @created[0], $dir, "created directory (old style 3 mode undef) cross-check"
is: (rmtree: $dir), 1, "removed directory 3 verbose undef"

$dir = catdir: $tmp_base,'G'
$dir = (VMS::Filespec::unixify: $dir) if $Is_VMS

@created = mkpath: $dir, undef, 0200
is: (scalar: nelems @created), 1, "created write-only dir"
is: @created[0], $dir, "created write-only directory cross-check"
is: (rmtree: $dir), 1, "removed write-only dir"

# borderline new-style heuristics
if (chdir $tmp_base)
    pass: "chdir to temp dir"
else
    fail: "chdir to temp dir: $^OS_ERROR"


$dir   = catdir: 'a', 'd1'
$dir2  = catdir: 'a', 'd2'

@created = mkpath:  $dir, 0, $dir2 
is: scalar nelems @created, 3, 'new-style 3 dirs created'

$count = rmtree:  $dir, 0, $dir2, 
is: $count, 3, 'new-style 3 dirs removed'

@created = mkpath:  $dir, $dir2, 1 
is: scalar nelems @created, 3, 'new-style 3 dirs created (redux)'

$count = rmtree:  $dir, $dir2, 1 
is: $count, 3, 'new-style 3 dirs removed (redux)'

@created = mkpath:  $dir, $dir2 
is: scalar nelems @created, 2, 'new-style 2 dirs created'

$count = rmtree:  $dir, $dir2 
is: $count, 2, 'new-style 2 dirs removed'

if (chdir (updir: ))
    pass: "chdir parent"
else
    fail: "chdir parent: $^OS_ERROR"


# see what happens if a file exists where we want a directory
:SKIP do
    my $entry = catdir: $tmp_base, "file"
    skip: "Cannot create $entry", 4 unless open: my $out, ">", " $entry"
    print: $out, "test file, safe to delete\n", (scalar: localtime), "\n"
    close $out
    ok: -e $entry, "file exists in place of directory"

    mkpath:  $entry, \(%: error => \$error) 
    is:  (scalar: nelems $error->@), 1, "caught error condition" 
    (@: $file, $message) =@:  each $error->[0]->%
    is:  $entry, $file, "and the message is: $message"

    try {@created = (mkpath: $entry, 0, 0700)}
    $error = $^EVAL_ERROR
    chomp $error # just to remove silly # in TAP output
    cmp_ok:  $error, 'ne', "", "no directory created (old-style) err=$error" 
        or diag: < @created


my $extra =  catdir: (curdir: ), < qw(EXTRA 1 a)

:SKIP do
    skip: "extra scenarios not set up, see eg/setup-extra-tests", 14
        unless -e $extra

    my ($list, $err)
    $dir = catdir:  'EXTRA', '1' 
    rmtree:  $dir, \(%: result => \$list, error => \$err) 
    is: (scalar: nelems $list->@), 2, "extra dir $dir removed"
    is: (scalar: nelems $err->@), 1, "one error encountered"

    $dir = catdir:  'EXTRA', '3', 'N' 
    rmtree:  $dir, \(%: result => \$list, error => \$err) 
    is:  (nelems $list->@), 1, q{remove a symlinked dir} 
    is:  (nelems $err->@),  0, q{with no errors} 

    $dir = catdir: 'EXTRA', '3', 'S'
    rmtree: $dir, \(%: error => \$error)
    is:  (scalar: nelems $error->@), 1, 'one error for an unreadable dir' 
    try { (@: $file, $message) =(@:  each $error->[0]->%)}
    is:  $file, $dir, 'unreadable dir reported in error' 
        or diag: $message

    $dir = catdir: 'EXTRA', '3', 'T'
    rmtree: $dir, \(%: error => \$error)
    is:  (scalar: nelems $error->@), 1, 'one error for an unreadable dir T' 
    try { (@: $file, $message) =(@:  each $error->[0]->%)}
    is:  $file, $dir, 'unreadable dir reported in error T' 

    $dir = catdir:  'EXTRA', '4' 
    rmtree: $dir,  \(%: result => \$list, error => \$err) 
    is:  (scalar: nelems $list->@), 0, q{don't follow a symlinked dir} 
    is:  (scalar: nelems $err->@),  2, q{two errors when removing a symlink in r/o dir} 
    try { (@: $file, $message) =(@:  each $err->[0]->%) }
    is:  $file, $dir, 'symlink reported in error' 

    $dir  = catdir: 'EXTRA', '3', 'U'
    $dir2 = catdir: 'EXTRA', '3', 'V'
    rmtree: $dir, $dir2, \(%: verbose => 0, error => \$err, result => \$list)
    is:  (scalar: nelems $list->@),  1, q{deleted 1 out of 2 directories} 
    is:  (scalar: nelems $error->@), 1, q{left behind 1 out of 2 directories} 
    try { (@: $file, $message) =(@:  each $err->[0]->%) }
    is:  $file, $dir, 'first dir reported in error' 


:SKIP do
    skip: 'Test::Output not available', 14
        unless $has_Test_Output

    :SKIP do
        $dir = catdir: 'EXTRA', '3'
        skip: "extra scenarios not set up, see eg/setup-extra-tests", 3
            unless -e $dir

        $dir = catdir: 'EXTRA', '3', 'U'
        stderr_like: 
            sub (@< @_) {(rmtree: $dir, \(%: verbose => 0))}
            qr{\Acannot make child directory read-write-exec for [^:]+: .* at \S+ line \d+}
            q(rmtree can't chdir into root dir)
            

        $dir = catdir: 'EXTRA', '3'
        stderr_like: 
            sub (@< @_) {(rmtree: $dir, \$%)}
            qr{\Acannot make child directory read-write-exec for [^:]+: .* at (\S+) line (\d+)
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot remove directory for [^:]+: .* at \1 line \2}
            'rmtree with file owned by root'
            

        stderr_like: 
            sub (@< @_) {(rmtree: 'EXTRA', \$%)}
            qr{\Acannot remove directory for [^:]+: .* at (\S+) line (\d+)
cannot remove directory for [^:]+: .* at \1 line \2
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot remove directory for [^:]+: .* at \1 line \2
cannot unlink file for [^:]+: .* at \1 line \2
cannot restore permissions to \d+ for [^:]+: .* at \1 line \2
cannot make child directory read-write-exec for [^:]+: .* at \1 line \2
cannot remove directory for [^:]+: .* at \1 line \2
cannot restore permissions to \d+ for [^:]+: .* at \1 line \2}
            'rmtree with insufficient privileges'
            
    

    my $base = catdir: $tmp_base,'output'
    $dir  = catdir: $base,'A'
    $dir2 = catdir: $base,'B'

    stderr_like: 
        sub (@< @_) { (rmtree:  undef, 1 ) }
        qr/\ANo root path\(s\) specified\b/
        "rmtree of nothing carps sensibly"
        

    stderr_like: 
        sub (@< @_) { (rmtree:  '', 1 ) }
        qr/\ANo root path\(s\) specified\b/
        "rmtree of empty dir carps sensibly"
        

    stderr_is:  sub (@< @_) { (mkpath: ) }, '', "mkpath no args does not carp" 
    stderr_is:  sub (@< @_) { (rmtree: ) }, '', "rmtree no args does not carp" 

    stdout_is: 
        sub (@< @_) {@created = (mkpath: $dir, 1)}
        "mkdir $base\nmkdir $dir\n"
        'mkpath verbose (old style 1)'
        

    stdout_is: 
        sub (@< @_) {@created = (mkpath: \(@: $dir2), 1)}
        "mkdir $dir2\n"
        'mkpath verbose (old style 2)'
        

    stdout_is: 
        sub (@< @_) {$count = (rmtree: \(@: $dir, $dir2), 1, 1)}
        "rmdir $dir\nrmdir $dir2\n"
        'rmtree verbose (old style)'
        

    stdout_is: 
        sub (@< @_) {@created = (mkpath: $dir, \(%: verbose => 1, mask => 0750))}
        "mkdir $dir\n"
        'mkpath verbose (new style 1)'
        

    stdout_is: 
        sub (@< @_) {@created = (mkpath: $dir2, 1, 0771)}
        "mkdir $dir2\n"
        'mkpath verbose (new style 2)'
        

    :SKIP do
        $file = catdir: $dir2, "file"
        skip: "Cannot create $file", 2 unless open: my $out, ">", " $file"
        print: $out, "test file, safe to delete\n", (scalar: localtime), "\n"
        close $out

        ok: -e $file, "file created in directory"

        stdout_is: 
            sub (@< @_) {$count = (rmtree: $dir, $dir2, \(%: verbose => 1, safe => 1))}
            "rmdir $dir\nunlink $file\nrmdir $dir2\n"
            'rmtree safe verbose (new style)'
            
    


:SKIP do
    skip: "extra scenarios not set up, see eg/setup-extra-tests", 11
        unless -d catdir:  <qw(EXTRA 1)

    rmtree: 'EXTRA', \%: safe => 0, error => \$error
    is:  (scalar: nelems $error->@), 11, 'seven deadly sins'  # well there used to be 7

    rmtree: 'EXTRA', \%: safe => 1, error => \$error
    is:  (scalar: nelems $error->@), 9, 'safe is better' 
    for ( $error->@)
        (@: $file, $message) =@:  each $_->%
        if ($file =~  m/[123]\z/)
            is: (index: $message, 'cannot remove directory: '), 0, "failed to remove $file with rmdir"
                or diag: $message
        else
            like: $message, qr(\Acannot (?:restore permissions to \d+|chdir to child|unlink file): ), "failed to remove $file with unlink"
                or diag: $message
        
    


rmtree: $tmp_base, \(%: result => \$list) 
is: (ref: $list), 'ARRAY', "received a final list of results"
ok:  !(-d $tmp_base), "test base directory gone" 
