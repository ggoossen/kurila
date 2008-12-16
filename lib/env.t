BEGIN {
    require "./test.pl";
}
plan tests => 6;
use env;

is( env::var("PERL_CORE"), 1, "PERL_CORE is set to '1'" );
is( env::var("PERL_DO_NOT_EXIST"), undef, "PERL_DO_NOT_EXIST does not exist" );

env::set_var("PERL_TEST_ENV_VAR", "test1");
is( env::var("PERL_TEST_ENV_VAR"), "test1", "PERL_TEST_ENV_VAR was set" );
env::set_var("PERL_TEST_ENV_VAR", "test2");
is( env::var("PERL_TEST_ENV_VAR"), "test2", "PERL_TEST_ENV_VAR adjusted" );

fresh_perl_is(qq{print env::var("PERL_TEST_ENV_VAR")},
              "test2",
              \%(),
              "PERL_TEST_ENV_VAR passed through to child");

env::set_var("PERL_TEST_ENV_VAR", undef);
is( env::var("PERL_TEST_ENV_VAR"), undef, "PERL_TEST_ENV_VAR is undef" );
