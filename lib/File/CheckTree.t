#!./perl -w

use Test::More

BEGIN { (plan: tests => 8) }


BEGIN 
    # Cwd::cwd does an implicit "require Win32", but
    # the ../lib directory in $^INCLUDE_PATH will no longer work once
    # we chdir() out of the "t" directory.
    if ($^OS_NAME eq 'MSWin32')
        require Win32
        Win32->import
    


use File::CheckTree
use File::Spec          # used to get absolute paths

# We assume that we start from the perl "t" directory.
# Will move up one level to make it easier to generate
# reliable pathnames for testing File::CheckTree

chdir: File::Spec->updir or die: "cannot change to parent of t/ directory: $^OS_ERROR"


#### TEST 1 -- No warnings ####
# usings both relative and full paths, indented comments

do
    my ($num_warnings, $path_to_README)
    $path_to_README = File::Spec->rel2abs: 'README'

    my @warnings
    local $^WARN_HOOK = sub (@< @_) { (push: @warnings, @_[0]->{?description}) }

    try {
        $num_warnings = validate: qq{
            lib  -d
# comment, followed "blank" line (w/ whitespace):
           
            # indented comment, followed blank line (w/o whitespace):

            README -f
            '$path_to_README' -e || warn
        };
    }

    for (@warnings)
        print: $^STDERR, $_
    if ( !$^EVAL_ERROR && !@warnings && (defined: $num_warnings) && $num_warnings == 0 )
        ok: 1
    else
        ok: 0
    



#### TEST 2 -- One warning ####

do
    my ($num_warnings, @warnings)

    local $^WARN_HOOK = sub (@< @_) { (push: @warnings, @_[0]->{?description}) }

    try {
        $num_warnings = validate: qq{
            lib    -f
            README -f
        };
    }

    if ( !$^EVAL_ERROR && (nelems @warnings) == 1
           && @warnings[0] =~ m/lib is not a plain file/
           && defined: $num_warnings
        && $num_warnings == 1 )
        ok: 1
    else
        ok: 0


#### TEST 3 -- Multiple warnings ####
# including first warning only from a bundle of tests,
# generic "|| warn", default "|| warn" and "|| warn '...' "

do
    my ($num_warnings, @warnings)

    local $^WARN_HOOK = sub (@< @_) { (push: @warnings, @_[0]->{?description}) }

    try {
        $num_warnings = validate: q{
            lib     -effd
            README -f || die
            README -d || warn
            lib    -f || warn: "my warning: $file\n"
        };
    }

    if ( !$^EVAL_ERROR && (nelems @warnings) == 3
           && @warnings[0] =~ m/lib is not a plain file/
           && @warnings[1] =~ m/README is not a directory/
           && @warnings[2] =~ m/my warning: lib/
           && defined: $num_warnings
        && $num_warnings == 3 )
        ok: 1
    else
        ok: 0


#### TEST 4 -- cd directive ####
# cd directive followed by relative paths, followed by full paths
do
    my ($num_warnings, @warnings, $path_to_libFile, $path_to_dist)
    $path_to_libFile = File::Spec->rel2abs: (File::Spec->catdir: 'lib','File')
    $path_to_dist    = File::Spec->rel2abs: File::Spec->curdir

    local $^WARN_HOOK = sub (@< @_) { (push: @warnings, @_[0]->{?description}) }

    try {
        $num_warnings = validate: qq{
            lib                -d || die
            '$path_to_libFile' cd
            Spec               -e
            Spec               -f
            '$path_to_dist'    cd
            README             -ef
            INSTALL            -d || warn
            '$path_to_libFile' -d || die
        };
    }

    if ( !$^EVAL_ERROR && (nelems @warnings) == 2
           && @warnings[0] =~ m/Spec is not a plain file/
           && @warnings[1] =~ m/INSTALL is not a directory/
           && defined: $num_warnings
        && $num_warnings == 2 )
        ok: 1
    else
        ok: 0


#### TEST 5 -- Exception ####
# test with generic "|| die"
do
    my $num_warnings

    try {
        $num_warnings = validate: q{
            lib       -ef || die
            README    -d
        };
    }

    if ( $^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/lib is not a plain file/
        && not defined $num_warnings )
        ok: 1
    else
        ok: 0, "$^EVAL_ERROR"
    



#### TEST 6 -- Exception ####
# test with "|| die 'my error message'"
do
    my $num_warnings

    try {
        $num_warnings = validate: q{
            lib       -ef || die: "yadda $file yadda...\n"
            README    -d
        };
    }

    if ( $^EVAL_ERROR && $^EVAL_ERROR->{?description} =~ m/yadda lib yadda/
        && not defined $num_warnings )
        ok: 1
    else
        ok: 0


#### TEST 7 -- Quoted file names ####
do
    my $num_warnings
    try {
        $num_warnings = validate: q{
            "a file with whitespace" !-ef
            'a file with whitespace' !-ef
        };
    }

    if ( !$^EVAL_ERROR )
        # No errors mean we compile correctly
        ok: 1
    else
        ok: 0
        print: $^STDERR, $^EVAL_ERROR
    ;


#### TEST 8 -- Malformed query ####
do
    my $num_warnings
    try {
        $num_warnings = validate: q{
            a file with whitespace !-ef
        };
    }

    # We got a syntax error for a malformed file query
    like:  $^EVAL_ERROR->message, qr/syntax error/

