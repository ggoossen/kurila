package MakeUtil ;
package main ;
 

use Config;
use File::Copy;


BEGIN
{
    try { require File::Spec::Functions ; File::Spec::Functions->import() } ;
    if ($^EVAL_ERROR)
    {
        *catfile = sub { return "@_[0]/@_[1]" }
    }
}

require VMS::Filespec if $^OS_NAME eq 'VMS';


unless(env::var('PERL_CORE')) {
    env::var('PERL_CORE' ) = 1 if grep { $_ eq 'PERL_CORE=1' }, @ARGV;
}

env::var('SKIP_FOR_CORE' ) = 1 if env::var('PERL_CORE') || env::var('MY_PERL_CORE') ;



sub MY::libscan
{
    my $self = shift;
    my $path = shift;

    return undef
        if $path =~ m/(~|\.bak|_bak)$/ ||
           $path =~ m/\..*\.sw(o|p)$/  ||
           $path =~ m/\B\.svn\b/;

    return $path;
}

sub MY::postamble 
{
    return ''
        if env::var('PERL_CORE') ;

    my @files = getPerlFiles('MANIFEST');

    my $postamble = '

MyTrebleCheck:
	@echo Checking for $$^W in files: '. "$(join ' ',@files)" . q|
	@perl -ne '						\
	    exit 1 if /^\s*local\s*\(\s*\$$\^W\s*\)/;		\
         ' | . " $(join ' ',@files) || " . '				\
	(echo found unexpected $$^W ; exit 1)
	@echo All is ok.

';

    return $postamble;
}

sub getPerlFiles
{
    my @manifests = @_ ;

    my @files = @( () );

    for my $manifest ( @manifests)
    {
        my $prefix = './';

        $prefix = $1
            if $manifest =~ m#^(.*/)#;

        open my $m, "<", "$manifest"
            or die "Cannot open '$manifest': $^OS_ERROR\n";
        while ( ~< $m)
        {
            chomp ;
            next if m/^\s*#/ || m/^\s*$/ ;

            s/^\s+//;
            s/\s+$//;

            m/^(\S+)\s*(.*)$/;

            my @($file, $rest) = @($1, $2);

            if ($file =~ m/\.(pm|pl|t)$/ and $file !~ m/MakeUtil.pm/)
            {
                push @files, "$prefix$file";
            }
            elsif ($rest =~ m/perl/i)
            {
                push @files, "$prefix$file";
            }

        }
        close $m;
    }

    return @files;
}

package MakeUtil ;

1;


