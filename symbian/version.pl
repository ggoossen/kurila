

my %VERSION;

if (open(PATCHLEVEL_H, "<", "patchlevel.h")) {
  while ( ~< *PATCHLEVEL_H) {
     if (m/#define\s+PERL_(REVISION|VERSION|SUBVERSION)\s+(\d+)/) {
         %VERSION{+$1} = $2;
     }
  }
  close PATCHLEVEL_H;
} else {
  die "$^PROGRAM_NAME: patchlevel.h: $^OS_ERROR\n";
}

die "$^PROGRAM_NAME: Perl release looks funny.\n"
  unless (defined %VERSION{?REVISION} && %VERSION{?REVISION} == 5 &&
          defined %VERSION{?VERSION}  && %VERSION{?VERSION}  +>= 8 &&
          defined %VERSION{?SUBVERSION});


\%VERSION;
