#!perl -w

# creates perllibst.h file for inclusion from perllib.c

use Config

my @statics = split: m/\s+/, config_value: 'static_ext'
open: my $fh, '>', 'perllibst.h' or die: "Failed to write to perllibst.h:$^OS_ERROR"

my @statics1 = map: {s/\//__/g;$_}, @statics
my @statics2 = map: {s/\//::/g;$_}, @statics
print: $fh, "/*DO NOT EDIT\n  this file is included from perllib.c to init static extensions */\n"
print: $fh, "#ifdef STATIC1\n",(< (map: {"    \"$_\",\n"}, @statics)),"#undef STATIC1\n#endif\n"
print: $fh, "#ifdef STATIC2\n",(< (map: {"    EXTERN_C void boot_$_ (pTHX_ CV* cv);\n"}, @statics1)),"#undef STATIC2\n#endif\n"
print: $fh, "#ifdef STATIC3\n",(< (map: {"    newXS(\"@statics2[$_]::bootstrap\", boot_@statics1[$_], file);\n"}, 0 .. (nelems: @statics)-1)),"#undef STATIC3\n#endif\n"
close $fh
