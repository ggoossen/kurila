#!./perl
use FileCache maxopen=>2;
use vars qw(@files);
BEGIN {
    @files = qw(foo bar baz quux Foo_Bar);
    chdir 't' if -d 't';

    #For tests within the perl distribution
    @INC = '../lib' if -d '../lib';
    END;
}
END{
  1 while unlink @files;
}

print "1..2\n";

{# Test 3: that we open for append on second viewing
     my @cat;
     for my $path ( @files ){
         my $sym = Symbol::qualify_to_ref($path);
	 cacheout $path;
	 print $sym "$path 3\n";
     }
     for my $path ( @files ){
         my $sym = Symbol::qualify_to_ref($path);
	 cacheout $path;
	 print $sym "$path 33\n";
     }
     for my $path ( @files ){
         my $sym = Symbol::qualify_to_ref($path);
	 open($sym, '<', $path);
	 push @cat, do{ local $/; <$sym>};
         close($sym);
     }
     print 'not ' unless scalar grep(/\b3$/m, @cat) == scalar @files;
     print "ok 1\n";
     @cat = ();
     for my $path ( @files ){
         my $sym = Symbol::qualify_to_ref($path);
	 cacheout $path;
	 print $sym "$path 333\n";
     }
     for my $path ( @files ){
         my $sym = Symbol::qualify_to_ref($path);
	 open($sym, '<', $path);
	 push @cat, do{ local $/; <$sym>};
         close($sym);
     }
     print 'not ' unless scalar grep(/\b33$/m, @cat) == scalar @files;
     print "ok 2\n";
}
