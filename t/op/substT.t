#!perl -wT

for my $file (@('op/subst.t', 't/op/subst.t', ':op:subst.t')) {
  if (-r $file) {
    do ($^OS_NAME eq 'MacOS' ?? $file !! "./$file");
    exit;
  }
}
die "Cannot find op/subst.t or t/op/subst.t\n";
