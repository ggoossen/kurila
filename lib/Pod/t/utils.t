
# Test hyperlinks et al from Pod::ParseUtils

use warnings
use Test::More tests => 21

use Pod::ParseUtils

# First test the hyperlinks

my @links = qw{
  name
  name/ident
  name/"sec"
  "sec"
  /"sec"
  http://www.perl.org/
  text|name
  text|name/ident
  text|name/"sec"
  text|"sec"
}

my @results = @:
        "P<name>"
        "Q<ident> in P<name>"
        "Q<sec> in P<name>"
        "Q<sec>"
        "Q<sec>"
        "Q<http://www.perl.org/>"
        "Q<text>"
        "Q<text>"
        "Q<text>"
        "Q<text>"
    

for my $i( 0..nelems @links )
    my $link = Pod::Hyperlink->new:  @links[?$i]
    is: ($link->markup: ), @results[?$i]


# Now test lists
# This test needs to be better
my $list = Pod::List->new:  indent => 4
                            start  => 52
                            file   => "itemtest.t"
                            type   => "OL",

ok: $list

is: ($list->indent: ), 4
is: ($list->start: ), 52
is: ($list->type: ), "OL"


# Pod::Cache

# also needs work

my $cache = Pod::Cache->new: 

# Store it in the cache
$cache->item: 
    page => "Pod::ParseUtils"
    description => "A description"
    file => "file.t"
    

# Now look for an item of this name
my $item = $cache->find_page: "Pod::ParseUtils"
ok: $item

# and a failure
is: ($cache->find_page: "Junk"), undef

# Make sure that the item we found is the same one as the
# first in the list
my @i = $cache->item: 
cmp_ok: @i[0], '\==', $item

# Check the contents
is: ($item->page: ), "Pod::ParseUtils"
is: ($item->description: ), "A description"
is: ($item->file: ), "file.t"
