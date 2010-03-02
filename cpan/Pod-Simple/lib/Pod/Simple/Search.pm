
package Pod::Simple::Search


our ($VERSION, $MAX_VERSION_WITHIN, $SLEEPY)
$VERSION = 3.04   ## Current version of this package

BEGIN
    *DEBUG = sub () {0} unless exists &DEBUG   # set DEBUG level

use Carp ()

$SLEEPY = 1 if !defined $SLEEPY and $^OS_NAME =~ m/mswin|mac/i
# flag to occasionally sleep for $SLEEPY - 1 seconds.

$MAX_VERSION_WITHIN ||= 60

#############################################################################

#use diagnostics;
use File::Spec ()
use File::Basename < qw( basename )
use Config ()
use Cwd < qw( cwd )

#==========================================================================
__PACKAGE__->_accessorize:   # Make my dumb accessor methods
    'callback', 'progress', 'dir_prefix', 'inc', 'laborious', 'limit_glob'
    'limit_re', 'shadows', 'verbose', 'name2path', 'path2name'
    
#==========================================================================

sub new($class)
    my $self = bless: \$%, (ref: $class) || $class
    $self->init
    return $self


sub init
    my $self = shift
    $self->inc: 1
    $self->verbose:  (DEBUG: )
    return $self


#--------------------------------------------------------------------------

sub survey($self, @< @search_dirs)
    $self = $self->new unless ref $self # tolerate being a class method

    $self->_expand_inc:  \@search_dirs 


    $self->{+'_scan_count'} = 0
    $self->{+'_dirs_visited'} = \$%
    $self->path2name:  \$% 
    $self->name2path:  \$% 
    $self->limit_re:  $self->_limit_glob_to_limit_re  if $self->{?'limit_glob'}
    my $cwd = (cwd: )
    my $verbose  = $self->verbose
    local $_ = undef # don't clobber the caller's $_ !

    foreach my $try ( @search_dirs)
        unless( (File::Spec->file_name_is_absolute: $try) )
            # make path absolute
            $try = File::Spec->catfile:  $cwd ,$try
        
        # simplify path
        $try =  File::Spec->canonpath: $try

        my $start_in
        my $modname_prefix
        if($self->{?'dir_prefix'})
            $start_in = File::Spec->catdir: 
                $try
                < grep: { (length: $_) }, split: '[\/:]+', $self->{?'dir_prefix'}
                
            $modname_prefix = \ grep: { (length: $_) }, split: m{[:/\\]}, $self->{?'dir_prefix'}
            $verbose and print: $^STDOUT, "Appending \"$self->{?'dir_prefix'}\" to $try, "
                                "giving $start_in (= $((join: ' ',$modname_prefix->@)))\n"
        else
            $start_in = $try
        

        if( $self->{'_dirs_visited'}->{?$start_in} )
            $verbose and print: $^STDOUT, "Directory '$start_in' already seen, skipping.\n"
            next
        else
            $self->{'_dirs_visited'}->{+$start_in} = 1
        

        unless(-e $start_in)
            $verbose and print: $^STDOUT, "Skipping non-existent $start_in\n"
            next
        

        my $closure = $self->_make_search_callback

        if(-d $start_in)
            # Normal case:
            $verbose and print: $^STDOUT, "Beginning excursion under $start_in\n"
            $self->_recurse_dir:  $start_in, $closure, $modname_prefix 
            $verbose and print: $^STDOUT, "Back from excursion under $start_in\n\n"

        elsif(-f _)
            # A excursion consisting of just one file!
            $_ = basename: $start_in
            $verbose and print: $^STDOUT, "Pondering $start_in ($_)\n"
            $closure->& <: $start_in, $_, 0, \$@

        else
            $verbose and print: $^STDOUT, "Skipping mysterious $start_in\n"
        
    
    $self->progress and $self->progress->done: 
        "Noted $self->{?'_scan_count'} Pod files total"

    return $self->name2path



#==========================================================================
sub _make_search_callback($self)
    # Put the options in variables, for easy access
    my(@:   $laborious, $verbose, $shadows, $limit_re, $callback, $progress,$path2name,$name2path) =
        map: { (scalar: ($self->?$_: )) },
                 qw(laborious   verbose   shadows   limit_re   callback   progress  path2name  name2path)

    my($file, $shortname, $isdir, $modname_bits)
    return sub ($file, $shortname, $isdir, $modname_bits)

        if($isdir) # this never gets called on the startdir itself, just subdirs

            if( $self->{'_dirs_visited'}->{?$file} )
                $verbose and print: $^STDOUT, "Directory '$file' already seen, skipping.\n"
                return 'PRUNE'
            

            print: $^STDOUT, "Looking in dir $file\n" if $verbose

            unless ($laborious) # $laborious overrides pruning
                if( m/^([A-Za-z][a-zA-Z0-9_]*)\z/s )
                    $verbose and print: $^STDOUT, "$_ is a well-named module subdir.  Looking....\n"
                else
                    $verbose and print: $^STDOUT, "$_ is a fishy directory name.  Skipping.\n"
                    return 'PRUNE'
                
             # end unless $laborious

            $self->{'_dirs_visited'}->{+$file} = 1
            return # (not pruning);
        


        # Make sure it's a file even worth even considering
        if($laborious)
            unless(
                      m/\.(pod|pm|plx?)\z/i || -x _ and -T _
                # Note that the cheapest operation (the RE) is run first.
                )
                $verbose +> 1 and print: $^STDOUT, " Brushing off uninteresting $file\n"
                return
            
        else
            unless( m/^[-_a-zA-Z0-9]+\.(?:pod|pm|plx?)\z/is )
                $verbose +> 1 and print: $^STDOUT, " Brushing off oddly-named $file\n"
                return
            
        

        $verbose and print: $^STDOUT, "Considering item $file\n"
        my $name = $self->_path2modname:  $file, $shortname, $modname_bits 
        $verbose +> 0.01 and print: $^STDOUT, " Nominating $file as $name\n"

        if($limit_re and $name !~ m/$limit_re/i)
            $verbose and print: $^STDOUT, "Shunning $name as not matching $limit_re\n"
            return

        if( !$shadows and $name2path->{?$name} )
            $verbose and print: $^STDOUT, "Not worth considering $file "
                                "-- already saw $name as "
                                (join: ' ', (grep:  {$path2name->{?$_} eq $name }, keys $path2name->%)), "\n"
            return

        # Put off until as late as possible the expense of
        #  actually reading the file:
        if( m/\.pod\z/is ) {
        # just assume it has pod, okay?
        }else
            $progress and $progress->reach: $self->{?'_scan_count'}, "Scanning $file"
            return unless $self->contains_pod:  $file 
        
        ++ $self->{+'_scan_count'}

        # Or finally take note of it:
        if( $name2path->{?$name} )
            $verbose and print: $^STDOUT
                                "Duplicate POD found (shadowing?): $name ($file)\n"
                                "    Already seen in "
                                (join: ' ', (grep:  {$path2name->{?$_} eq $name }, keys $path2name->%)), "\n"
        else
            $name2path->{+$name} = $file # Noting just the first occurrence
        
        $verbose and print: $^STDOUT, "  Noting $name = $file\n"
        if( $callback )
            local $_ = $_ # insulate from changes, just in case
            $callback->& <: $file, $name
        
        $path2name->{+$file} = $name
        return
    


#==========================================================================

sub _path2modname($self, $file, $shortname, $modname_bits)

    # this code simplifies the POD name for Perl modules:
    # * remove "site_perl"
    # * remove e.g. "i586-linux" (from 'archname')
    # * remove e.g. 5.00503
    # * remove pod/ if followed by perl*.pod (e.g. in pod/perlfunc.pod)
    # * dig into the file for case-preserved name if not already mixed case

    my @m = $modname_bits->@
    my $x
    my $verbose = $self->verbose

    # Shaving off leading naughty-bits
    while((nelems @m)
            and defined: ($x = (lc:  @m[0] ))
            and(  $x eq 'site_perl'
              or($x eq 'pod' and (nelems @m) == 1 and $shortname =~ m{^perl.*\.pod$}s )
              or $x =~ m{\\d+\\.z\\d+([_.]?\\d+)?}  # if looks like a vernum
              or $x eq lc:  (Config::config_value: 'archname') 
              )) { shift @m }

    my $name = join: '::', @:  < @m, $shortname
    $name = $self->_simplify_base: $name

    # On VMS, case-preserved document names can't be constructed from
    # filenames, so try to extract them from the "=head1 NAME" tag in the
    # file instead.
    if ($^OS_NAME eq 'VMS' && ($name eq (lc: $name) || $name eq (uc: $name)))
        open: my $podfile, "<", "$file" or die: "_path2modname: Can't open $file: $^OS_ERROR"
        my $in_pod = 0
        my $in_name = 0
        my $line
        while ($line = ~< $podfile)
            chomp $line
            $in_pod = 1 if ($line =~ m/^=\w/)
            $in_pod = 0 if ($line =~ m/^=cut/)
            next unless $in_pod         # skip non-pod text
            next if ($line =~ m/^\s*\z/)           # and blank lines
            next if ($in_pod && ($line =~ m/^X</)) # and commands
            if ($in_name)
                if ($line =~ m/(\w+::)?(\w+)/)
                    # substitute case-preserved version of name
                    my $podname = $2
                    my $prefix = $1 || ''
                    $verbose and print: $^STDOUT, "Attempting case restore of '$name' from '$prefix$podname'\n"
                    unless ($name =~ s/$prefix$podname/$prefix$podname/i)
                        $verbose and print: $^STDOUT, "Attempting case restore of '$name' from '$podname'\n"
                        $name =~ s/$podname/$podname/i
                    
                    last
                
            
            $in_name = 1 if ($line =~ m/^=head1 NAME/)
        
        close $podfile
    

    return $name


#==========================================================================

sub _recurse_dir($self, $startdir, $callback, $modname_bits)

    my $maxdepth = $self->{?'fs_recursion_maxdepth'} || 10
    my $verbose = $self->verbose

    my $here_string = File::Spec->curdir
    my $up_string   = File::Spec->updir
    $modname_bits ||= \$@

    my $recursor
    $recursor = sub ($dir_long, $dir_bare)
        if( (nelems $modname_bits->@) +>= 10 )
            $verbose and print: $^STDOUT, "Too deep! [$((join: ' ',$modname_bits->@))]\n"
            return
        

        unless(-d $dir_long)
            $verbose +> 2 and print: $^STDOUT, "But it's not a dir! $dir_long\n"
            return
        
        my $indir
        unless( (opendir: $indir, $dir_long) )
            $verbose +> 2 and print: $^STDOUT, "Can't opendir $dir_long : $^OS_ERROR\n"
            closedir: $indir
            return
        
        my @items = sort: @:  readdir: $indir
        closedir: $indir

        push: $modname_bits->@, $dir_bare unless $dir_bare eq ''

        my $i_full
        foreach my $i ( @items)
            next if $i eq $here_string or $i eq $up_string or $i eq ''
            $i_full = File::Spec->catfile:  $dir_long, $i 

            if(!-r $i_full)
                $verbose and print: $^STDOUT, "Skipping unreadable $i_full\n"

            elsif(-f $i_full)
                $_ = $i
                $callback->& <:           $i_full, $i, 0, $modname_bits 

            elsif(-d _)
                $i =~ s/\.DIR\z//i if $^OS_NAME eq 'VMS'
                $_ = $i
                my $rv =( $callback->& <:  $i_full, $i, 1, $modname_bits ) || ''

                if($rv eq 'PRUNE')
                    $verbose +> 1 and print: $^STDOUT, "OK, pruning"
                else
                    # Otherwise, recurse into it
                    $recursor->& <:  (File::Spec->catdir: $dir_long, $i) , $i
                
            else
                $verbose +> 1 and print: $^STDOUT, "Skipping oddity $i_full\n"
            
        
        pop $modname_bits->@
        return
    ;

    local $_ = undef
    $recursor->& <: $startdir, ''

    undef $recursor  # allow it to be GC'd

    return



#==========================================================================

sub run(?$file, ?$name)
    # A function, useful in one-liners

    my $self = __PACKAGE__->new
    $self->limit_glob: @ARGV[0] if (nelems @ARGV)
    $self->callback:  sub ()
                          my $version = ''

        # Yes, I know we won't catch the version in like a File/Thing.pm
        #  if we see File/Thing.pod first.  That's just the way the
        #  cookie crumbles.  -- SMB

                          my $inpod
                          if($file =~ m/\.pod$/i)
            # Don't bother looking for $VERSION in .pod files
                              DEBUG: and print: $^STDOUT, "Not looking for \$VERSION in .pod $file\n"
                          elsif( !(open: $inpod, "<", $file) )
                              DEBUG: and print: $^STDOUT, "Couldn't open $file: $^OS_ERROR\n"
                              close: $inpod
                          else
            # Sane case: file is readable
                              my $lines = 0
                              while( ~< $inpod)
                                  last if $lines++ +> $MAX_VERSION_WITHIN # some degree of sanity
                                  if( s/^\s*\$VERSION\s*=\s*//s and m/\d/ )
                                      DEBUG: and print: $^STDOUT, "Found version line (#$lines): $_"
                                      s/\s*\#.*//s
                                      s/\;\s*$//s
                                      s/\s+$//s
                                      s/\t+/ /s # nix tabs
                    # Optimize the most common cases:
                                      $_ = "v$1"
                                          if m{^v?["']?([0-9_]+(\.[0-9_]+)*)["']?$}s
                          # like in $VERSION = "3.14159";
                                        or m{\$Revision:\s*([0-9_]+(?:\.[0-9_]+)*)\s*\$}s
                    # like in sprintf("%d.%02d", q$Revision: 4.13 $ =~ /(\d+)\.(\d+)/);


                    # Like in sprintf("%d.%s", map {s/_//g; $_} q$Name: release-0_55-public $ =~ /-(\d+)_([\d_]+)/)
                                      $_ = sprintf: "v\%d.\%s"
                                                    < (map: {s/_//g; $_},
                                                                (@:               $1 =~ m/-(\d+)_([\d_]+)/)) # snare just the numeric part
                                          if m{\$Name:\s*([^\$]+)\$}s

                                      $version = $_
                                      DEBUG: and print: $^STDOUT, "Noting $version as version\n"
                                      last


                              close: $inpod

                          print: $^STDOUT, "$name\t$version\t$file\n"
                          return
      # End of callback!
      

    $self->survey


#==========================================================================

sub simplify_name($self, $str)

    # Remove all path components
    #                             XXX Why not just use basename()? -- SMB

    if ($^OS_NAME eq 'MacOS') { $str =~ s{^.*:+}{}s }
    else                { $str =~ s{^.*/+}{}s }

    $str = $self->_simplify_base: $str
    return $str


#==========================================================================

sub _simplify_base($self, $base)   # Internal method only

    # strip Perl's own extensions
    $base =~ s/\.(pod|pm|plx?)\z//i

    # strip meaningless extensions on Win32 and OS/2
    $base =~ s/\.(bat|exe|cmd)\z//i if $^OS_NAME =~ m/mswin|os2/i

    # strip meaningless extensions on VMS
    $base =~ s/\.(com)\z//i if $^OS_NAME eq 'VMS'

    return $base


#==========================================================================

sub _expand_inc($self, $search_dirs)

    return unless $self->{?'inc'}

    if ($^OS_NAME eq 'MacOS')
        push: $search_dirs->@
              < grep: { $_ ne File::Spec->curdir }, $self->_mac_whammy: < $^INCLUDE_PATH
    # Any other OSs need custom handling here?
    else
        push: $search_dirs->@, < grep: { $_ ne File::Spec->curdir }, $^INCLUDE_PATH
    

    $self->{+'laborious'} = 0   # Since inc said to use INC
    return


#==========================================================================

sub _mac_whammy(_,@< @them) # Tolerate '.', './some_dir' and '(../)+some_dir' on Mac OS
    my @them

    for my $_ ( @them)
        if ( $_ eq '.' )
            $_ = ':'
        elsif ( $_ =~ s|^((?:\.\./)+)|$(':' x ((length: $1)/3))| )
            $_ = ':'. $_
        else
            $_ =~ s|^\./|:|
        
    
    return @them


#==========================================================================

sub _limit_glob_to_limit_re
    my $self = @_[0]
    my $limit_glob = $self->{?'limit_glob'} || return

    my $limit_re = '^' . (quotemeta: $limit_glob) . '$'
    $limit_re =~ s/\\\?/./g    # glob "?" => "."
    $limit_re =~ s/\\\*/.*?/g  # glob "*" => ".*?"
    $limit_re =~ s/\.\*\?\$$//s # final glob "*" => ".*?$" => ""

    $self->{?'verbose'} and print: $^STDOUT, "Turning limit_glob $limit_glob into re $limit_re\n"

    # A common optimization:
    if(!exists: $self->{'dir_prefix'}
         and $limit_glob =~ m/^(?:\w+\:\:)+/s  # like "File::*" or "File::Thing*"
        # Optimize for sane and common cases (but not things like "*::File")
        )
        $self->{+'dir_prefix'} = join: "::", @:  $limit_glob =~ m/^(?:\w+::)+/sg
        $self->{?'verbose'} and print: $^STDOUT, " and setting dir_prefix to $self->{?'dir_prefix'}\n"
    

    return $limit_re


#==========================================================================

# contribution mostly from Tim Jenness <t.jenness@jach.hawaii.edu>

sub find($self, $pod, @< @search_dirs)
    $self = $self->new unless ref $self # tolerate being a class method

    # Check usage
    Carp::carp:  'Usage: \$self->find($podname, ...)'
        unless defined $pod and length $pod

    my $verbose = $self->verbose

    # Split on :: and then join the name together using File::Spec
    my @parts = split: m/::/, $pod
    $verbose and print: $^STDOUT, "Chomping \{$pod\} => \{$((join: ' ',@parts))\}\n"

    #@search_dirs = File::Spec->curdir unless @search_dirs;

    if( $self->inc )
        if( $^OS_NAME eq 'MacOS' )
            push: @search_dirs, < $self->_mac_whammy: < $^INCLUDE_PATH
        else
            push: @search_dirs,                    < $^INCLUDE_PATH
        

        # Add location of pod documentation for perl man pages (eg perlfunc)
        # This is a pod directory in the private install tree
        #my $perlpoddir = File::Spec->catdir(Config::config_value('installprivlib'),
        #					'pod');
        #push (@search_dirs, $perlpoddir)
        #  if -d $perlpoddir;

        # Add location of binaries such as pod2text:
        push: @search_dirs, Config::config_value: 'scriptdir'
    # and if that's undef or q{} or nonexistent, we just ignore it later
    

    my %seen_dir
    :Dir
        foreach my $dir (  @search_dirs )
        next unless defined $dir and length $dir
        next if %seen_dir{?$dir}
        %seen_dir{+$dir} = 1
        unless(-d $dir)
            print: $^STDOUT, "Directory $dir does not exist\n" if $verbose
            next Dir
        

        print: $^STDOUT, "Looking in directory $dir\n" if $verbose
        my $fullname = File::Spec->catfile:  $dir, < @parts 
        print: $^STDOUT, "Filename is now $fullname\n" if $verbose

        foreach my $ext ((@: '', '.pod', '.pm', '.pl'))   # possible extensions
            my $fullext = $fullname . $ext
            if( -f $fullext  and  $self->contains_pod:  $fullext  )
                print: $^STDOUT, "FOUND: $fullext\n" if $verbose
                return $fullext
            
        
        my $subdir = File::Spec->catdir: $dir,'pod'
        if(-d $subdir)  # slip in the ./pod dir too
            $verbose and print: $^STDOUT, "Noticing $subdir and stopping there...\n"
            $dir = $subdir
            redo Dir
        
    

    return undef


#==========================================================================

sub contains_pod($self, $file)
    my $verbose = $self->{?'verbose'}

    # check for one line of POD
    $verbose +> 1 and print: $^STDOUT, " Scanning $file for pod...\n"
    my $maybepod
    unless( (open: $maybepod, "<","$file") )
        print: $^STDOUT, "Error: $file is unreadable: $^OS_ERROR\n"
        return undef
    

    sleep: $SLEEPY - 1 if $SLEEPY
    # avoid totally hogging the processor on OSs with poor process control

    local $_ = undef
    while( ~< $maybepod )
        if(m/^=(head\d|pod|over|item)\b/s)
            (close: $maybepod) || die: "Bizarre error closing $file: $^OS_ERROR\nAborting"
            chomp
            $verbose +> 1 and print: $^STDOUT, "  Found some pod ($_) in $file\n"
            return 1
        
    
    (close: $maybepod) || die: "Bizarre error closing $file: $^OS_ERROR\nAborting"
    $verbose +> 1 and print: $^STDOUT, "  No POD in $file, skipping.\n"
    return 0


#==========================================================================

sub _accessorize  # A simple-minded method-maker
    shift
    foreach my $attrname ( @_)
        (Symbol::fetch_glob: (caller: ) . '::' . $attrname)->* = sub (@< @_)
            die: "Accessor usage: \$obj->$attrname() or \$obj->$attrname(\$new_value)"
                unless ((nelems @_) == 1 or (nelems @_) == 2) and ref @_[0]

            # Read access:
            return @_[0]->{?$attrname} if (nelems @_) == 1

            # Write access:
            @_[0]->{+$attrname} = @_[1]
            return @_[0] # RETURNS MYSELF!
    
    # Ya know, they say accessories make the ensemble!
    return


#==========================================================================
sub _state_as_string
    my $self = @_[0]
    return '' unless ref $self
    my @out = @:  "\{\n  # State of $((dump::view: $self)) ...\n" 
    foreach my $k ((sort: keys $self->%))
        push: @out, "  $((dump::view: $k)) => $((dump::view: $self->{?$k}))\n"
    
    push: @out, "\}\n"
    my $x = join: '', @out
    $x =~ s/^/#/mg
    return $x


#==========================================================================

run:  unless caller  # run if "perl whatever/Search.pm"

1

#==========================================================================

__END__


=head1 NAME

Pod::Simple::Search - find POD documents in directory trees

=head1 SYNOPSIS

  use Pod::Simple::Search;
  my $name2path = Pod::Simple::Search->new->limit_glob('LWP::*')->survey;
  print "Looky see what I found: ",
    join(' ', sort keys %$name2path), "\n";

  print "LWPUA docs = ",
    Pod::Simple::Search->new->find('LWP::UserAgent') || "?",
    "\n";

=head1 DESCRIPTION

B<Pod::Simple::Search> is a class that you use for running searches
for Pod files.  An object of this class has several attributes
(mostly options for controlling search options), and some methods
for searching based on those attributes.

The way to use this class is to make a new object of this class,
set any options, and then call one of the search options
(probably C<survey> or C<find>).  The sections below discuss the
syntaxes for doing all that.


=head1 CONSTRUCTOR

This class provides the one constructor, called C<new>.
It takes no parameters:

  use Pod::Simple::Search;
  my $search = Pod::Simple::Search->new;

=head1 ACCESSORS

This class defines several methods for setting (and, occasionally,
reading) the contents of an object. With two exceptions (discussed at
the end of this section), these attributes are just for controlling the
way searches are carried out.

Note that each of these return C<$self> when you call them as
C<< $self->I<whatever(value)> >>.  That's so that you can chain
together set-attribute calls like this:

  my $name2path =
    Pod::Simple::Search->new
    -> inc(0) -> verbose(1) -> callback(\&blab)
    ->survey(@there);

...which works exactly as if you'd done this:

  my $search = Pod::Simple::Search->new;
  $search->inc(0);
  $search->verbose(1);
  $search->callback(\&blab);
  my $name2path = $search->survey(@there);

=over

=item $search->inc( I<true-or-false> );

This attribute, if set to a true value, means that searches should
implicitly add perl's I<$^INCLUDE_PATH> paths. This
automatically considers paths specified in the C<PERL5LIB> environment
as this is prepended to I<$^INCLUDE_PATH> by the Perl interpreter itself.
This attribute's default value is B<TRUE>.  If you want to search
only specific directories, set $self->inc(0) before calling
$inc->survey or $inc->find.


=item $search->verbose( I<nonnegative-number> );

This attribute, if set to a nonzero positive value, will make searches output
(via C<warn>) notes about what they're doing as they do it.
This option may be useful for debugging a pod-related module.
This attribute's default value is zero, meaning that no C<warn> messages
are produced.  (Setting verbose to 1 turns on some messages, and setting
it to 2 turns on even more messages, i.e., makes the following search(es)
even more verbose than 1 would make them.)


=item $search->limit_glob( I<some-glob-string> );

This option means that you want to limit the results just to items whose
podnames match the given glob/wildcard expression. For example, you
might limit your search to just "LWP::*", to search only for modules
starting with "LWP::*" (but not including the module "LWP" itself); or
you might limit your search to "LW*" to see only modules whose (full)
names begin with "LW"; or you might search for "*Find*" to search for
all modules with "Find" somewhere in their full name. (You can also use
"?" in a glob expression; so "DB?" will match "DBI" and "DBD".)


=item $search->callback( I<\&some_routine> );

This attribute means that every time this search sees a matching
Pod file, it should call this callback routine.  The routine is called
with two parameters: the current file's filespec, and its pod name.
(For example: C<("/etc/perljunk/File/Crunk.pm", "File::Crunk")> would
be in C<@_>.)

The callback routine's return value is not used for anything.

This attribute's default value is false, meaning that no callback
is called.

=item $search->laborious( I<true-or-false> );

Unless you set this attribute to a true value, Pod::Search will 
apply Perl-specific heuristics to find the correct module PODs quickly.
This attribute's default value is false.  You won't normally need
to set this to true.

Specifically: Turning on this option will disable the heuristics for
seeing only files with Perl-like extensions, omitting subdirectories
that are numeric but do I<not> match the current Perl interpreter's
version ID, suppressing F<site_perl> as a module hierarchy name, etc.


=item $search->shadows( I<true-or-false> );

Unless you set this attribute to a true value, Pod::Simple::Search will
consider only the first file of a given modulename as it looks thru the
specified directories; that is, with this option off, if
Pod::Simple::Search has seen a C<somepathdir/Foo/Bar.pm> already in this
search, then it won't bother looking at a C<somelaterpathdir/Foo/Bar.pm>
later on in that search, because that file is merely a "shadow". But if
you turn on C<< $self->shadows(1) >>, then these "shadow" files are
inspected too, and are noted in the pathname2podname return hash.

This attribute's default value is false; and normally you won't
need to turn it on.


=item $search->limit_re( I<some-regxp> );

Setting this attribute (to a value that's a regexp) means that you want
to limit the results just to items whose podnames match the given
regexp. Normally this option is not needed, and the more efficient
C<limit_glob> attribute is used instead.


=item $search->dir_prefix( I<some-string-value> );

Setting this attribute to a string value means that the searches should
begin in the specified subdirectory name (like "Pod" or "File::Find",
also expressable as "File/Find"). For example, the search option
C<< $search->limit_glob("File::Find::R*") >>
is the same as the combination of the search options
C<< $search->limit_re("^File::Find::R") -> dir_prefix("File::Find") >>.

Normally you don't need to know about the C<dir_prefix> option, but I
include it in case it might prove useful for someone somewhere.

(Implementationally, searching with limit_glob ends up setting limit_re
and usually dir_prefix.)


=item $search->progress( I<some-progress-object> );

If you set a value for this attribute, the value is expected
to be an object (probably of a class that you define) that has a 
C<reach> method and a C<done> method.  This is meant for reporting
progress during the search, if you don't want to use a simple
callback.

Normally you don't need to know about the C<progress> option, but I
include it in case it might prove useful for someone somewhere.

While a search is in progress, the progress object's C<reach> and
C<done> methods are called like this:

  # Every time a file is being scanned for pod:
  $progress->reach($count, "Scanning $file");   ++$count;

  # And then at the end of the search:
  $progress->done("Noted $count Pod files total");

Internally, we often set this to an object of class
Pod::Simple::Progress.  That class is probably undocumented,
but you may wish to look at its source.


=item $name2path = $self->name2path;

This attribute is not a search parameter, but is used to report the
result of C<survey> method, as discussed in the next section.

=item $path2name = $self->path2name;

This attribute is not a search parameter, but is used to report the
result of C<survey> method, as discussed in the next section.

=back

=head1 MAIN SEARCH METHODS

Once you've actually set any options you want (if any), you can go
ahead and use the following methods to search for Pod files
in particular ways.


=head2 C<< $search->survey( @directories ) >>

The method C<survey> searches for POD documents in a given set of
files and/or directories.  This runs the search according to the various
options set by the accessors above.  (For example, if the C<inc> attribute
is on, as it is by default, then the perl $^INCLUDE_PATH directories are implicitly
added to the list of directories (if any) that you specify.)

The return value of C<survey> is two hashes:

=over

=item C<name2path>

A hash that maps from each pod-name to the filespec (like
"Stuff::Thing" => "/whatever/plib/Stuff/Thing.pm")

=item C<path2name>

A hash that maps from each Pod filespec to its pod-name (like
"/whatever/plib/Stuff/Thing.pm" => "Stuff::Thing")

=back

Besides saving these hashes as the hashref attributes
C<name2path> and C<path2name>, calling this function also returns
these hashrefs.  In list context, the return value of
C<< $search->survey >> is the list C<(\%name2path, \%path2name)>.
In scalar context, the return value is C<\%name2path>.
Or you can just call this in void context.

Regardless of calling context, calling C<survey> saves
its results in its C<name2path> and C<path2name> attributes.

E.g., when searching in F<$HOME/perl5lib>, the file
F<$HOME/perl5lib/MyModule.pm> would get the POD name I<MyModule>,
whereas F<$HOME/perl5lib/Myclass/Subclass.pm> would be
I<Myclass::Subclass>. The name information can be used for POD
translators.

Only text files containing at least one valid POD command are found.

In verbose mode, a warning is printed if shadows are found (i.e., more
than one POD file with the same POD name is found, e.g. F<CPAN.pm> in
different directories).  This usually indicates duplicate occurrences of
modules in the I<$^INCLUDE_PATH> search path, which is occasionally inadvertent
(but is often simply a case of a user's path dir having a more recent
version than the system's general path dirs in general.)

The options to this argument is a list of either directories that are
searched recursively, or files.  (Usually you wouldn't specify files,
but just dirs.)  Or you can just specify an empty-list, as in
$name2path; with the
C<inc> option on, as it is by default, teh

The POD names of files are the plain basenames with any Perl-like
extension (.pm, .pl, .pod) stripped, and path separators replaced by
C<::>'s.

Calling Pod::Simple::Search->search(...) is short for
Pod::Simple::Search->new->search(...).  That is, a throwaway object
with default attribute values is used.


=head2 C<< $search->simplify_name( $str ) >>

The method B<simplify_name> is equivalent to B<basename>, but also
strips Perl-like extensions (.pm, .pl, .pod) and extensions like
F<.bat>, F<.cmd> on Win32 and OS/2, or F<.com> on VMS, respectively.


=head2 C<< $search->find( $pod ) >>

=head2 C<< $search->find( $pod, @search_dirs ) >>

Returns the location of a Pod file, given a Pod/module/script name
(like "Foo::Bar" or "perlvar" or "perldoc"), and an idea of
what files/directories to look in.
It searches according to the various options set by the accessors above.
(For example, if the C<inc> attribute is on, as it is by default, then
the perl $^INCLUDE_PATH directories are implicitly added to the list of
directories (if any) that you specify.)

This returns the full path of the first occurrence to the file.
Package names (eg 'A::B') are automatically converted to directory
names in the selected directory.  Additionally, '.pm', '.pl' and '.pod'
are automatically appended to the search as required.
(So, for example, under Unix, "A::B" is converted to "somedir/A/B.pm",
"somedir/A/B.pod", or "somedir/A/B.pl", as appropriate.)

If no such Pod file is found, this method returns undef.

If any of the given search directories contains a F<pod/> subdirectory,
then it is searched.  (That's how we manage to find F<perlfunc>,
for example, which is usually in F<pod/perlfunc> in most Perl dists.)

The C<verbose> and C<inc> attributes influence the behavior of this
search; notably, C<inc>, if true, adds $^INCLUDE_PATH I<and also
Config::config_value('scriptdir')> to the list of directories to search.

It is common to simply say C<< $filename = Pod::Simple::Search-> new 
->find("perlvar") >> so that just the $^INCLUDE_PATH (well, and scriptdir)
directories are searched.  (This happens because the C<inc>
attribute is true by default.)

Calling Pod::Simple::Search->find(...) is short for
Pod::Simple::Search->new->find(...).  That is, a throwaway object
with default attribute values is used.


=head2 C<< $self->contains_pod( $file ) >>

Returns true if the supplied filename (not POD module) contains some Pod
documentation.


=head1 AUTHOR

Sean M. Burke E<lt>sburke@cpan.orgE<gt>
borrowed code from
Marek Rouchal's Pod::Find, which in turn
heavily borrowed code from Nick Ing-Simmons' PodToHtml.

Tim Jenness E<lt>t.jenness@jach.hawaii.eduE<gt> provided
C<find> and C<contains_pod> to Pod::Find.

=head1 SEE ALSO

L<Pod::Simple>, L<Pod::Perldoc>

=cut

