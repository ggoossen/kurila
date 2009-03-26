$^OUTPUT_AUTOFLUSH++;
print "# Child has TTY? " . (-t $^STDIN ?? "YES" !! "NO" ) . $^INPUT_RECORD_SEPARATOR;
print $_ = ~< *ARGV;

