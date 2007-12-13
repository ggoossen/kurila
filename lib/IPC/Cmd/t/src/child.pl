$|++;
print "# Child has TTY? " . (-t *STDIN ? "YES" : "NO" ) . $/;
print $_ = ~< *ARGV;

