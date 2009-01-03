#!./perl
require './test.pl';

$^INPLACE_EDIT = $^OS_NAME eq 'VMS' ?? '_bak' !! '.bak';

plan( tests => 2 );

my @tfiles     = @('.a','.b','.c');
my @tfiles_bak = @(".a$^INPLACE_EDIT", ".b$^INPLACE_EDIT", ".c$^INPLACE_EDIT");

END { unlink_all('.a','.b','.c',".a$^INPLACE_EDIT", ".b$^INPLACE_EDIT", ".c$^INPLACE_EDIT"); }

for my $file ( @tfiles) {
    runperl( prog => 'print qq(foo\n);', 
             args => \@('>', $file) );
}

@ARGV = @tfiles;

while ( ~< *ARGV) {
    s/foo/bar/;
}
continue {
    print;
}

is ( runperl( prog => 'print ~< *ARGV;', args => \@tfiles ), 
     "bar\nbar\nbar\n", 
     "file contents properly replaced" );

is ( runperl( prog => 'print ~< *ARGV;', args => \@tfiles_bak ), 
     "foo\nfoo\nfoo\n", 
     "backup file contents stay the same" );

