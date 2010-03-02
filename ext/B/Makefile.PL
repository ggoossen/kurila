use ExtUtils::MakeMaker
use Config
use File::Spec

my $e = config_value: 'exe_ext'
my $o = config_value: 'obj_ext'
my $exeout_flag = '-o '
my $core = grep: { $_ eq 'PERL_CORE=1' }, @ARGV
if ($^OS_NAME eq 'MSWin32')
    if ((config_value: 'cc') =~ m/^cl/i)
        $exeout_flag = '-Fe'
    elsif ((config_value: 'cc') =~ m/^bcc/i)
        $exeout_flag = '-e'
    


WriteMakefile: 
    NAME            => "B"
    VERSION_FROM    => "B.pm"
    PL_FILES        => (%:  'defsubs_h.PL' => 'defsubs.h' )
    clean           => %:
        FILES           => "perl$e *$o B.c defsubs.h *~"
    
    

package MY

use Config

sub post_constants
    "\nLIBS = $((config_value: 'libs'))\n"


sub headerpath
    if ($core)
        return File::Spec->catdir:  File::Spec->updir
                                    File::Spec->updir
    else
        return File::Spec->catdir: (config_value: "archlibexp"), "CORE"
    


sub MY::postamble($self)
    my $headerpath = (headerpath: )
    my @headers = map: { (File::Spec->catfile: $headerpath, $_) }, qw(op.h cop.h)
    my $noecho = $self->{?NOECHO}

    "
B\$(OBJ_EXT) : defsubs.h

defsubs.h :: $((join: ' ',@headers)) defsubs_h.PL
	\$(PERL) -I\$(INST_ARCHLIB) -I\$(INST_LIB) -I\$(PERL_ARCHLIB) -I\$(PERL_LIB) defsubs_h.PL defsubs.h $headerpath
"


sub MY::processPL($self, @< @_)
    my $text = $self->SUPER::processPL: < @_
    # Append our extra parameter
    $text =~ s/^(\t.*defsubs_h\.PL.*)/$1 $((headerpath: ))/m
    $text

