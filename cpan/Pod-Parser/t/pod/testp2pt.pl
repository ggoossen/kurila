package TestPodIncPlainText

BEGIN 
    use File::Basename
    use File::Spec
    use Cwd < qw(abs_path)
    push: $^INCLUDE_PATH, '..'
    my $THISDIR = abs_path: (dirname: $^PROGRAM_NAME)
    unshift: $^INCLUDE_PATH, $THISDIR
    require "testcmp.pl"
    TestCompare->import
    my $PARENTDIR = dirname: $THISDIR
    push: $^INCLUDE_PATH, < map: { ('File::Spec'->catfile: $_, 'lib') }, @:  ($PARENTDIR, $THISDIR)


#use diagnostics;
use Exporter
#use File::Compare;
#use Cwd qw(abs_path);

our ($MYPKG, @EXPORT, @ISA)
$MYPKG = try { (@: caller)[0] }
@EXPORT = qw(&testpodplaintext)
BEGIN 
    require Pod::PlainText
    @ISA = qw( Pod::PlainText )
    require VMS::Filespec if $^OS_NAME eq 'VMS'


## Hardcode settings for TERMCAP and COLUMNS so we can try to get
## reproducible results between environments
(env::var: 'TERMCAP' ) = 'co=76:do=^J'
(env::var: 'COLUMNS' ) = 76

sub catfile(@< @args) { ('File::Spec'->catfile: < @args); }

my $INSTDIR = abs_path: (dirname: $^PROGRAM_NAME)
$INSTDIR = (VMS::Filespec::unixpath: $INSTDIR) if $^OS_NAME eq 'VMS'
$INSTDIR =~ s#/$## if $^OS_NAME eq 'VMS'
$INSTDIR =~ s#:$## if $^OS_NAME eq 'MacOS'
$INSTDIR = ((dirname: $INSTDIR)) if ((basename: $INSTDIR) eq 'pod')
$INSTDIR =~ s#:$## if $^OS_NAME eq 'MacOS'
$INSTDIR = ((dirname: $INSTDIR)) if ((basename: $INSTDIR) eq 't')
my @PODINCDIRS = @: catfile: $INSTDIR, 'lib', 'Pod'
                    catfile: $INSTDIR, 'scripts'
                    catfile: $INSTDIR, 'pod'
                    catfile: $INSTDIR, 't', 'pod'

# FIXME - we should make the core capable of finding utilities built in
# locations in ext.
push: @PODINCDIRS, (catfile: < (@: File::Spec->updir) x 2, 'pod') if env::var: 'PERL_CORE'

## Find the path to the file to =include
sub findinclude
    my $self    = shift
    my $incname = shift

    ## See if its already found w/out any "searching;
    return  $incname if (-r $incname)

    ## Need to search for it. Look in the following directories ...
    ##   1. the directory containing this pod file
    my $thispoddir = dirname: $self->input_file
    ##   2. the parent directory of the above
    my $parentdir  = dirname: $thispoddir
    my @podincdirs = @: $thispoddir, $parentdir, < @PODINCDIRS

    for ( @podincdirs)
        my $incfile = catfile: $_, $incname
        return $incfile  if (-r $incfile)
    
    warn: "*** Can't find =include file $incname in $((join: ' ',@podincdirs))\n"
    return ""


sub command
    my $self = shift
    my (@: $cmd, $text, $line_num, $pod_para)  =  @_
    $cmd     = ''  unless (defined $cmd)
    local $_ = $text || ''
    my $out_fh  = $self->output_handle

    ## Defer to the superclass for everything except '=include'
    return  ($self->SUPER::command: < @_) unless ($cmd eq "include")

    ## We have an '=include' command
    my $incdebug = 1 ## debugging
    my @incargs = split: 
    if ((nelems @incargs) == 0)
        warn: "*** No filename given for '=include'\n"
        return
    
    my $incfile  = ($self->findinclude: shift @incargs)  or  return
    my $incbase  = basename: $incfile
    print: $out_fh, "###### begin =include $incbase #####\n"  if ($incdebug)
    $self->parse_from_file:  \(%: cutting => 1), $incfile 
    print: $out_fh, "###### end =include $incbase #####\n"    if ($incdebug)


sub begin_input
    @_[0]->{+_INFILE} = (VMS::Filespec::unixify: @_[0]->{?_INFILE}) if $^OS_NAME eq 'VMS'


sub podinc2plaintext($infile, $outfile)
    local $_ = undef
    my $text_parser = $MYPKG->new
    $text_parser->parse_from_file: $infile, $outfile


sub testpodinc2plaintext( %< %args )
    my $infile  = %args{?'In'}  || die: "No input file given!"
    my $outfile = %args{?'Out'} || die: "No output file given!"
    my $cmpfile = %args{?'Cmp'} || die: "No compare-result file given!"

    my $different = ''
    my $testname = basename: $cmpfile, '.t', '.xr'

    unless (-e $cmpfile)
        my $msg = "*** Can't find comparison file $cmpfile for testing $infile"
        warn: "$msg\n"
        return  $msg
    

    print: $^STDOUT, "# Running testpodinc2plaintext for '$testname'...\n"
    ## Compare the output against the expected result
    podinc2plaintext: $infile, $outfile
    if ( (testcmp: $outfile, $cmpfile) )
        $different = "$outfile is different from $cmpfile"
    else
        unlink: $outfile
    
    return  $different


sub testpodplaintext
    my %opts = %:  (ref @_[0] eq 'HASH') ?? < (shift: )->% !! () 
    my @testpods = @_
    my (@: $testname, $testdir) = @: "", ""
    my $cmpfile = ""
    my (@: $outfile, $errfile) = @: "", ""
    my $passes = 0
    my $failed = 0
    local $_ = undef

    print: $^STDOUT, "1..", scalar nelems @testpods, "\n"  unless (%opts{?'xrgen'})

    for my $podfile ( @testpods)
        (@: $testname, $_, ...) = fileparse: $podfile
        $testdir ||=  $_
        $testname  =~ s/\.t$//
        $cmpfile   =  $testdir . $testname . '.xr'
        $outfile   =  $testdir . $testname . '.OUT'

        if (%opts{?'xrgen'})
            if (%opts{?'force'} or ! -e $cmpfile)
                ## Create the comparison file
                print: $^STDOUT, "# Creating expected result for \"$testname\"" .
                           " pod2plaintext test ...\n"
                podinc2plaintext: $podfile, $cmpfile
            else
                print: $^STDOUT, "# File $cmpfile already exists" .
                           " (use 'force' to regenerate it).\n"
            
            next
        

        my $failmsg = testpodinc2plaintext: 
            In  => $podfile
            Out => $outfile
            Cmp => $cmpfile
        if ($failmsg)
            ++$failed
            print: $^STDOUT, "#\tFAILED. ($failmsg)\n"
            print: $^STDOUT, "not ok ", $failed+$passes, "\n"
        else
            ++$passes
            unlink: $outfile
            print: $^STDOUT, "#\tPASSED.\n"
            print: $^STDOUT, "ok ", $failed+$passes, "\n"
        
    
    return  $passes


1
