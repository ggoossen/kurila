#!./perl

BEGIN 
    require "./test.pl"


plan: tests => 2

is:  (dump::view: (%: key1 => "value1" ) +%+ (%: key2 => "value2" ) )
     (dump::view: %: key1 => "value1", key2 => "value2")
     "basic test" 
is:  (dump::view: (%: key => "value1" ) +%+ (%: key => "value2" ) )
     (dump::view: %: key => "value2")
     "duplicate keys" 
