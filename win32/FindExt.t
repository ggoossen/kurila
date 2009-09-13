#!../miniperl -w

BEGIN
    $^INCLUDE_PATH = qw(../win32 ../lib)

use Test::More tests => 10
use FindExt
use Config

FindExt::scan_ext('../ext')

# Config.pm and FindExt.pm make different choices about what should be built
my @config_built
my @found_built
do
    foreach my $type (qw(static dynamic nonxs))
        push @found_built, < eval "FindExt::$($type)_ext()"
        push @config_built, < split ' ', config_value("$($type)_ext")

@config_built = sort @config_built
@found_built = sort @found_built

foreach (@: @: 'static_ext'
               FindExt::static_ext()
               config_value('static_ext')
            @: 'nonxs_ext'
               FindExt::nonxs_ext()
               config_value('nonxs_ext')
            @: 'known_extensions'
               FindExt::known_extensions()
               config_value('known_extensions')
            @: '"config" dynamic + static + nonxs'
               @config_built,
               config_value('extensions')
            @: '"found" dynamic + static + nonxs'
               @found_built
               join " ", FindExt::extensions()
        )
    my @: $type, $found, $config = $_
    my @config = sort split ' ', $config
    is (nelems($found), nelems(@config),
        "We find the same number of $type")
    is_deeply($found, @config, "We find the same")
