#!perl -w
BEGIN 
    if( (env::var: 'PERL_CORE') )
        chdir 't' if -d 't'
        $^INCLUDE_PATH = @: '../lib'

use Test::More 'no_plan'

use Config::Extensions '%Extensions'

use Config

my @types = qw(dynamic static nonxs)
my %types
%types{[ @types]} =  @types

ok: nkeys %Extensions, "There are some extensions"
# Check only the 3 valid keys have been used.
while (my @: ?$key, ?$val = @: each %Extensions)
    my $raw_ext = $key
    # Back to the format in Config
    $raw_ext =~ s!::!/!g
    my $re = qr/\b\Q$raw_ext\E\b/
    like: (config_value: "extensions"), $re, "$key was built"
    unless (%types{$val})
        fail: "$key is $val"
        next
    
    my $type = $val . '_ext'
    like: (config_value: $type), $re, "$key is $type"

