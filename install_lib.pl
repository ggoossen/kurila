#!perl

# Initialisation code and subroutines shared between installperl and installman
# Probably installhtml needs to join the club.

our ($Is_VMS, $Is_W32, $Is_OS2, $Is_Cygwin, $Is_Darwin, $Is_NetWare,
     %opts, $packlist)

use Config
BEGIN
    if ((config_value: 'userelocatableinc'))
        # This might be a considered a hack. Need to get information about the
        # configuration from Config.pm *before* Config.pm expands any .../
        # prefixes.
        #
        # So we set $^X to pretend that we're the already installed perl, so
        # Config.pm doesits ... expansion off that location.

        my $location = config_value: 'initialinstalllocation'
        die: <<'OS' unless defined $location
$(config_value('initialinstalllocation')) is not defined - can't install a relocatable
perl without this.
OS
        $^EXECUTABLE_NAME = "$location/perl"
        # And then remove all trace of ever having loaded Config.pm, so that
        # it will reload with the revised $^X
        delete $^INCLUDED{"Config.pm"}
        delete $^INCLUDED{"Config_heavy.pl"}
        delete $^INCLUDED{"Config_git.pl"}
        # You never saw us. We weren't here.

        require Config
        Config->import: 

if ((config_value: 'd_umask'))
    umask: 022 # umasks like 077 aren't that useful for installations

$Is_VMS = $^OS_NAME eq 'VMS'
$Is_W32 = $^OS_NAME eq 'MSWin32'
$Is_OS2 = $^OS_NAME eq 'os2'
$Is_Cygwin = $^OS_NAME eq 'cygwin'
$Is_Darwin = $^OS_NAME eq 'darwin'
$Is_NetWare = (config_value: 'osname') eq 'NetWare'

sub unlink(@< @names)
    my($cnt) = 0

    return (scalar: @names) if $Is_VMS

    foreach my $name (@names)
        next unless -e $name
        chmod: 0777, $name if ($Is_OS2 || $Is_W32 || $Is_Cygwin || $Is_NetWare)
        print: $^STDOUT, "  unlink $name\n" if %opts{verbose}
        ( CORE::unlink: $name and ++$cnt
          or warn: "Couldn't unlink $name: $^OS_ERROR\n" ) unless %opts{notify}

    return $cnt

sub link($from,$to)
    my($success) = 0

    my $xfrom = $from
    $xfrom =~ s/^\Q%opts{destdir}\E// if %opts{destdir}
    my $xto = $to
    $xto =~ s/^\Q%opts{destdir}\E// if %opts{destdir}
    print: $^STDOUT, %opts{verbose} ?? "  ln $xfrom $xto\n" !! "  $xto\n"
        unless %opts{silent}
    try
        CORE::link: $from, $to
            ?? $success++
            !! ($from =~ m#^/afs/# || $to =~ m#^/afs/#)
              ?? die: "AFS"  # okay inside eval {}
              !! die: "Couldn't link $from to $to: $^OS_ERROR\n"
          unless %opts{notify}
        $packlist->{$xto} = %: from => $xfrom, type => 'link'

    if ($^EVAL_ERROR)
        warn: "Replacing link() with File::Copy::copy(): $(($^EVAL_ERROR->message: ))"
        print: $^STDOUT, %opts{verbose} ?? "  cp $from $xto\n" !! "  $xto\n"
            unless %opts{silent}
        print: $^STDOUT, "  creating new version of $xto\n"
                 if $Is_VMS and -e $to and !%opts{silent}
        unless (%opts{notify} or File::Copy::copy: $from, $to and ++$success)
            # Might have been that F::C::c can't overwrite the target
            warn: "Couldn't copy $from to $to: $^OS_ERROR\n"
                unless -f $to and do { chmod: 0666, $to; unlink: $to }
                        and File::Copy::copy: $from, $to and ++$success
        $packlist->{$xto} = %: type => 'file'

    return $success

sub chmod($mode,$name)
    return if ($^OS_NAME eq 'dos')
    printf: $^STDOUT, "  chmod \%o \%s\n", $mode, $name if %opts{verbose}
    CORE::chmod: $mode,$name
        || warn: sprintf: "Couldn't chmod \%o \%s: $^OS_ERROR\n", $mode, $name
      unless %opts{notify}


sub samepath($p1, $p2)
    return ((lc: $p1) eq (lc: $p2)) if ($Is_W32 || $Is_NetWare)

    if ($p1 ne $p2)
        my($dev1, $ino1, $dev2, $ino2)
        @: $dev1, $ino1, ... = @: stat: $p1
        @: $dev2, $ino2, ... = @: stat: $p2
        return ($dev1 == $dev2 && $ino1 == $ino2)
    else
        return 1
