# This -*- perl -*- script makes the Makefile
# $Id: Makefile.PL,v 1.3 1997/03/04 09:21:12 gbarr Exp $

use ExtUtils::MakeMaker;

#--- MY package

sub MY::libscan
{
  package MY;
  my($self, $path) = @_;
  return $path if $self->SUPER::libscan($path) and
                  $path !~ m! [~%]$
                            | \.(cache\.cm|swp|orig|rej)$
                            | regen\.pl$
                            !x;
  return '';
}

WriteMakefile(
	VERSION_FROM	=> "SysV.pm",
	NAME      	=> "IPC::SysV",
	MAN3PODS	=> {}, 	# Pods will be built by installman.
 
	'dist'    	=> {COMPRESS => 'gzip -9f',
			    SUFFIX   => 'gz', 
			    DIST_DEFAULT => 'all tardist',
			   },
 
	'clean'   	=> {FILES => join(" ",
					map { "$_ */$_ */*/$_" }
					qw(*% *.html *.b[ac]k *.old))
			   },
	'macro'		=> { INSTALLDIRS => 'perl' },
);
