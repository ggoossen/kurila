BEGIN 
    if((env::var: 'PERL_CORE'))
        chdir 't'
        $^INCLUDE_PATH = @:  '../lib' 
    


use Pod::Simple::Search
use Test::More
BEGIN { (plan: tests => 15) }

print: $^STDOUT, "# Some basic sanity tests...\n"

my $x = Pod::Simple::Search->new: 
die: "Couldn't make an object!?" unless ok: defined $x
print: $^STDOUT, "# New object: $((dump::view: $x))\n"
print: $^STDOUT, "# Version: ", ($x->VERSION: ), "\n"
ok: defined $x->can: 'callback'
ok: defined $x->can: 'dir_prefix'
ok: defined $x->can: 'inc'
ok: defined $x->can: 'laborious'
ok: defined $x->can: 'limit_glob'
ok: defined $x->can: 'limit_re'
ok: defined $x->can: 'shadows'
ok: defined $x->can: 'verbose'
ok: defined $x->can: 'survey'
ok: defined $x->can: '_state_as_string'
ok: defined $x->can: 'contains_pod'
ok: defined $x->can: 'find'
ok: defined $x->can: 'simplify_name'

print: $^STDOUT, "# Testing state dumping...\n"
print: $^STDOUT, $x->_state_as_string: 
$x->inc: "I\nLike  Pie!\t!!"
print: $^STDOUT, $x->_state_as_string: 

print: $^STDOUT, "# bye\n"
ok: 1

