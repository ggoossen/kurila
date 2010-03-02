#!/usr/bin/perl -w

BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't'
        $^INCLUDE_PATH = @: '../lib', 'lib'
    else
        unshift: $^INCLUDE_PATH, 't/lib'
    


use Test::More tests => 7

ok:  !(Test::Builder->is_fh: "foo"), 'string is not a filehandle' 
ok:  !(Test::Builder->is_fh: ''),    'empty string' 
ok:  !(Test::Builder->is_fh: undef), 'undef' 

ok:  (open: my $file, ">", 'foo') 
END { close $file; 1 while (unlink: 'foo') }

ok:  (Test::Builder->is_fh: \$file->*) 
ok:  (Test::Builder->is_fh: \$file->*) 

package Lying::isa

sub isa
    my $self = shift
    my $parent = shift

    return 1 if $parent eq 'IO::Handle'


main::ok:  (Test::Builder->is_fh: (bless: \$%, "Lying::isa"))
