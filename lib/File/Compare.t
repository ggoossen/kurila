#!./perl

BEGIN 
    chdir 't' if -d 't'
    $^INCLUDE_PATH = @:  '../lib' 


BEGIN 
    our @TEST = @:  stat "TEST" 
    our @README = @:  stat "README" 
    unless ((nelems @TEST) && nelems @README)
        print: $^STDOUT, "1..0 # Skip: no file TEST or README\n"
        exit 0
    


print: $^STDOUT, "1..13\n"

use File::Compare < qw(compare compare_text)

print: $^STDOUT, "ok 1\n"

# named files, same, existing but different, cause an error
print: $^STDOUT, "not " unless (compare: "README","README") == 0
print: $^STDOUT, "ok 2\n"

print: $^STDOUT, "not " unless (compare: "TEST","README") == 1
print: $^STDOUT, "ok 3\n"

print: $^STDOUT, "not " unless (compare: "README","HLAGHLAG") == -1
# a file which doesn't exist
print: $^STDOUT, "ok 4\n"

# compare_text, the same file, different but existing files
# cause error, test sub form.
print: $^STDOUT, "not " unless (compare_text: "README","README") == 0
print: $^STDOUT, "ok 5\n"

print: $^STDOUT, "not " unless (compare_text: "TEST","README") == 1
print: $^STDOUT, "ok 6\n"

print: $^STDOUT, "not " unless (compare_text: "TEST","HLAGHLAG") == -1
print: $^STDOUT, "ok 7\n"

print: $^STDOUT, "not " unless
    (compare_text: "README","README",sub (@< @_) {@_[0] ne @_[1]}) == 0
print: $^STDOUT, "ok 8\n"

# filehandle and same file
do
    my $fh
    open: $fh, "<", "README" or print: $^STDOUT, "not "
    binmode: $fh
    print: $^STDOUT, "not " unless (compare: $fh,"README") == 0
    print: $^STDOUT, "ok 9\n"
    close $fh


# filehandle and different (but existing) file.
do
    my $fh
    open: $fh, "<", "README" or print: $^STDOUT, "not "
    binmode: $fh
    print: $^STDOUT, "not " unless (compare_text: $fh,"TEST") == 1
    print: $^STDOUT, "ok 10\n"
    close $fh


# Different file with contents of known file,
# will use File::Temp to do this, skip rest of
# tests if this doesn't seem to work

my @donetests
try {
    require File::Spec; (File::Spec->import: );
    require File::Path; (File::Path->import: );
    require File::Temp; (File::Temp->import:  < qw/ :mktemp unlink0 /);

    my $template = (File::Spec->catfile: (File::Spec->tmpdir: ), 'fcmpXXXX');
    my(@: $tfh,$filename) =  (mkstemp: $template);
    # NB. The trailing space is intentional (see [perl #37716])
    open: my $tfhSP, ">", "$filename "
        or die: "Could not open '$filename ' for writing: $^OS_ERROR";
    (binmode: $tfhSP);
    do
        local $^INPUT_RECORD_SEPARATOR = undef #slurp
        my $fh
        open: $fh, "<",'README'
        binmode: $fh
        my $data = ~< $fh
        print: $tfh, $data
        close: $fh
        print: $tfhSP, $data
        close: $tfhSP
    ;
    (seek: $tfh,0,0);
    @donetests[0] = (compare: $tfh, 'README');
    @donetests[1] = (compare: $filename, 'README');
    (unlink0: $tfh,$filename);
    @donetests[2] = (compare: 'README', "$filename ");
    unlink: "$filename ";
}
print: $^STDOUT, "# problem '$(($^EVAL_ERROR->message: ))' when testing with a temporary file\n" if $^EVAL_ERROR

if ((nelems @donetests) == 3)
    print: $^STDOUT, "not " unless @donetests[0] == 0
    print: $^STDOUT, "ok 11 # fh/file [@donetests[0]]\n"
    print: $^STDOUT, "not " unless @donetests[1] == 0
    print: $^STDOUT, "ok 12 # file/file [@donetests[1]]\n"
    print: $^STDOUT, "not " unless @donetests[2] == 0
    print: $^STDOUT, "ok 13 # "
    print: $^STDOUT, "TODO" if $^OS_NAME eq "cygwin" # spaces after filename silently trunc'd
    print: $^STDOUT, " file/fileCR [@donetests[2]]\n"
else
    print: $^STDOUT, "ok 11# Skip\nok 12 # Skip\nok 13 # Skip Likely due to File::Temp\n"

