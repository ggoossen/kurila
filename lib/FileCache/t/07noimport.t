#!./perl -w

BEGIN {
    chdir 't';
    @INC = '../lib';
}

require './test.pl';
plan( tests => 1 );

# Try using FileCache without importing to make sure everything's 
# initialized without it.
{
    package Y;
    use FileCache ();

    my $file = 'foo';
    END { unlink $file }
    FileCache::cacheout($file);
    $file = Symbol::qualify_to_ref($file);
    print $file "bar";
    close $file;

    $file = 'foo';
    FileCache::cacheout("<", $file);
    ::ok( <$file> eq "bar" );
    close $file;
}
