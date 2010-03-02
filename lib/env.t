#! perl

BEGIN 
    require "./test.pl"

plan: tests => 9
use env

ok:  (env::var: "PERL_CORE"), "PERL_CORE is set" 
is:  (env::var: "PERL_DO_NOT_EXIST"), undef, "PERL_DO_NOT_EXIST does not exist" 

(env::var: "PERL_TEST_ENV_VAR") = "test1"
is:  (env::var: "PERL_TEST_ENV_VAR"), "test1", "PERL_TEST_ENV_VAR was set" 
(env::var: "PERL_TEST_ENV_VAR") = "test2"
is:  (env::var: "PERL_TEST_ENV_VAR"), "test2", "PERL_TEST_ENV_VAR adjusted" 

fresh_perl_is: qq{print: \$^STDOUT, env::var: "PERL_TEST_ENV_VAR"}
               "test2"
               \$%
               "PERL_TEST_ENV_VAR passed through to child"

(env::var: "PERL_TEST_ENV_VAR") = undef
is:  (env::var: "PERL_TEST_ENV_VAR"), undef, "PERL_TEST_ENV_VAR is undef" 

(env::var: "PERL_TEST_ENV_VAR") = "test3"
my %envhash = %:< @+: map: { @: $_ => (env::var: $_) }, (env::keys: ) 
ok:  %envhash{"PERL_CORE"} 
is:  %envhash{"PERL_TEST_ENV_VAR"}, "test3" 

do
    # setting to something with a '\0'
    local (env::var: "PERL_TEST_ENV_VAR") = "test\x[00]4"
    is: (env::var: "PERL_TEST_ENV_VAR"), "test\x[00]4"


my $v = env::var: "PERL_CORE"
(env::var: "PERL_CORE") = 1
$v = env::var: "PERL_CORE"
