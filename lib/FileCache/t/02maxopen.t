#!./perl
use FileCache maxopen=>2;
use Test;
use vars qw(@files);
BEGIN {
    @files = qw(foo bar baz quux);
    chdir 't' if -d 't';

    #For tests within the perl distribution
    @INC = '../lib' if -d '../lib';
    END;
    plan tests=>5;
}
END{
  1 while unlink @files;
}

{# Test 2: that we actually adhere to maxopen
  for my $path ( @files ){
    cacheout $path;
    my $sym = Symbol::fetch_glob($path);
    print $sym "$path 1\n";
  }
  
  my @cat;
  for my $path ( @files ){
    my $sym = Symbol::fetch_glob($path);
    ok(fileno($path) || $path =~ /^(?:foo|bar)$/);
    next unless fileno($path);
    print $sym "$path 2\n";
    close($sym);
    open($sym, $path);
    <$sym>;
    push @cat, <$sym>;
    close($sym);
  }
  ok( grep(/^(?:baz|quux) 2$/, @cat) == 2 );
}
