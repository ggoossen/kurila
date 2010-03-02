# This -*- perl -*- script makes the Makefile
# $Id: Makefile.PL,v 1.3 1997/03/04 09:21:12 gbarr Exp $

use ExtUtils::MakeMaker

#--- MY package

sub MY::libscan($self, $path)
    package MY

    return $path if $self->SUPER::libscan: $path and
      $path !~ m! [~%]$
                            | \.(cache\.cm|swp|orig|rej)$
                            | regen\.pl$
                            !x
    return ''


WriteMakefile: 
    VERSION_FROM        => "lib/IPC/SysV.pm"
    NAME        => "IPC::SysV"
    
