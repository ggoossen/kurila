#!./perl

BEGIN
    if ($^OS_NAME eq 'VMS')
        print: $^STDOUT, "1..0 # Skip on VMS -- too picky about line endings for record-oriented pipes\n"
        exit


require './test.pl'

my $Perl = (which_perl: )

my $data = <<'EOD'
x
 yy
z
EOD

(my $data2 = $data) =~ s/\n/\n\n/g

my $t1 = \%:  data => $data,  write_c => \(@: 1,2,length $data),  read_c => \(@: 1,2,3,length $data)
my $t2 = \%:  data => $data2, write_c => \(@: 1,2,length $data2), read_c => \(@: 1,2,3,length $data2)

my $c   # len write tests, for each: one _all test, and 3 each len+2
for (@: $t1, $t2)
    $c += (nelems $_->{?write_c}->@) * (1 + 3*nelems $_->{?read_c}->@)
$c *= 3*2*2     # $how_w, file/pipe, 2 reports

$c += 6 # Tests with sleep()...

print: $^STDOUT, "1..$c\n"

my $set_out = ''
$set_out = "binmode: \$^STDOUT, ':crlf'"
    if defined  $main::use_crlf && $main::use_crlf == 1

sub testread($fh, $str, $read_c, $how_r, $write_c, $how_w, $why)
    my $buf = ''
    if ($how_r eq 'readline_all')
        $buf .= $_ while ~< $fh
    elsif ($how_r eq 'readline')
        $^INPUT_RECORD_SEPARATOR = \$read_c
        $buf .= $_ while ~< $fh
    elsif ($how_r eq 'read')
        my($in, $c)
        $buf .= $in while $c = read: $fh, $in, $read_c
    elsif ($how_r eq 'sysread')
        my($in, $c)
        $buf .= $in while $c = sysread: $fh, $in, $read_c
    else
        die: "Unrecognized read: '$how_r'"

    close $fh or die: "close: $^OS_ERROR"
    # The only contamination allowed is with sysread/prints
    $buf =~ s/\r\n/\n/g if $how_r eq 'sysread' and $how_w =~ m/print/
    is: length $buf, length $str, "length with wrc=$write_c, rdc=$read_c, $how_w, $how_r, $why"
    is: $buf, $str, "content with wrc=$write_c, rdc=$read_c, $how_w, $how_r, $why"


sub testpipe($str, $write_c, $read_c, $how_w, $how_r, $why)
    (my $quoted = $str) =~ s/\n/\\n/g;
    my $fh
    if ($how_w eq 'print')      # AUTOFLUSH???
        # Should be shell-neutral:
        open: $fh, '-|', qq[$Perl -we "$set_out; for (grep: \{ length \}, split: m/(.\{1,$write_c\})/s, qq($quoted)) \{ print: \\\$^STDOUT, \\\$_; \} "] or die: "open: $^OS_ERROR"
    elsif ($how_w eq 'print/flush')
        # shell-neutral and miniperl-enabled autoflush? qq(\x24) eq '$'
        open: $fh, '-|', qq[$Perl -we "$set_out;eval qq(\\x24^OUTPUT_AUTOFLUSH = 1) or die:; for (grep: \{ length \}, split: m/(.\{1,$write_c\})/s, qq($quoted)) \{ print: \\\$^STDOUT, \\\$_ \} "] or die: "open: $^OS_ERROR"
    elsif ($how_w eq 'syswrite')
        ### How to protect \$_
        my $cmd = qq[$Perl -we "$set_out; sub w(\\\$_) \{ syswrite: \\\$^STDOUT, \\\$_ \} for (grep: \{ length \}, split: m/(.\{1,$write_c\})/s, qq($quoted)) \{ w(\\\$_) \}"]
        open: $fh, '-|', $cmd or die: "open '$cmd': $^OS_ERROR"
    else
        die: "Unrecognized write: '$how_w'"

    binmode: $fh, ':crlf'
        if defined $main::use_crlf && $main::use_crlf == 1
    testread: $fh, $str, $read_c, $how_r, $write_c, $how_w, "pipe$why"


sub testfile($str, $write_c, $read_c, $how_w, $how_r, $why)
    my @data = grep: { length }, split: m/(.{1,$write_c})/s, $str

    open: my $fh, '>', 'io_io.tmp' or die: 
    binmode: $fh, ':crlf'
        if defined $main::use_crlf && $main::use_crlf == 1
    if ($how_w eq 'print')      # AUTOFLUSH???
        $^OUTPUT_AUTOFLUSH = 0
        for (@data)
            print: $fh, $_
    elsif ($how_w eq 'print/flush')
        $^OUTPUT_AUTOFLUSH = 1
        for (@data)
            print: $fh, $_
    elsif ($how_w eq 'syswrite')
        for (@data)
            syswrite: $fh, $_
    else
        die: "Unrecognized write: '$how_w'"

    close $fh or die: "close: $^OS_ERROR"
    open: $fh, '<', 'io_io.tmp' or die: 
    binmode: $fh, ':crlf'
        if defined $main::use_crlf && $main::use_crlf == 1
    testread: $fh, $str, $read_c, $how_r, $write_c, $how_w, "file$why"


# shell-neutral and miniperl-enabled autoflush? qq(\x24) eq '$'
open: my $fh, '-|', qq[$Perl -we "eval qq(\\x24^OUTPUT_AUTOFLUSH = 1) or die:; binmode: \\\$^STDOUT; for (split: m//, qq(a\nb\n\nc\n\n\n)) \{ sleep: 1; print: \\\$^STDOUT, \\\$_; \}"] or die: "open: $^OS_ERROR"
ok: 1, 'open pipe'
binmode: $fh, q(:crlf)
ok: 1, 'binmode'
$c = undef
my @c
(push: @c, ord $c) while $c = getc $fh
(ok: 1, 'got chars'); is: scalar nelems @c, 9, 'got 9 chars'
is: "$((join: ' ',@c))", '97 10 98 10 10 99 10 10 10', 'got expected chars'
ok: (close: $fh), 'close'

for my $s (1..2)
    my $t = (@: $t1, $t2)[$s-1]
    my $str = $t->{?data}
    my $r = $t->{?read_c}
    my $w = $t->{?write_c}
    for my $read_c ( $r->@)
        for my $write_c ( $w->@)
            for my $how_r (qw(readline_all readline read sysread))
                next if $how_r eq 'readline_all' and $read_c != 1
                for my $how_w (qw(print print/flush syswrite))
                    testfile: $str, $write_c, $read_c, $how_w, $how_r, $s
                    testpipe: $str, $write_c, $read_c, $how_w, $how_r, $s

unlink: 'io_io.tmp'

1
