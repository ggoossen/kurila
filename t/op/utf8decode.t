#!./perl

do
    my $wide = "\x{100}"
    use bytes;
    my $ordwide = ord: $wide
    printf: $^STDOUT, "# under use bytes ord(v256) = 0x\%02x\n", $ordwide
    if ($ordwide == 140)
        print: $^STDOUT, "1..0 # Skip: UTF-EBCDIC (not UTF-8) used here\n"
        exit 0
    elsif ($ordwide != 196)
        printf: $^STDOUT, "# v256 starts with 0x\%02x\n", $ordwide
    


no utf8

print: $^STDOUT, "1..78\n"

my $test = 1

# This table is based on Markus Kuhn's UTF-8 Decode Stress Tester,
# http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt,
# version dated 2000-09-02.

# We use the \x notation instead of raw binary bytes for \x00-\x1f\x7f-\xff
# because e.g. many patch programs have issues with binary data.

my @MK = split: m/\n/, <<__EOMK__
1	Correct UTF-8
1.1.1 y "\x[ce]\x[ba]\x[e1]\x[bd]\x[b9]\x[cf]\x[83]\x[ce]\x[bc]\x[ce]\x[b5]"	-		11	ce:ba:e1:bd:b9:cf:83:ce:bc:ce:b5	5
2	Boundary conditions
2.1	First possible sequence of certain length
2.1.1 y "\x[00]"			0		1	00	1
2.1.2 y "\x[c2]\x[80]"			80		2	c2:80	1
2.1.3 y "\x[e0]\x[a0]\x[80]"		800		3	e0:a0:80	1
2.1.4 y "\x[f0]\x[90]\x[80]\x[80]"		10000		4	f0:90:80:80	1
2.1.5 y "\x[f8]\x[88]\x[80]\x[80]\x[80]"	200000		5	f8:88:80:80:80	1
2.1.6 y "\x[fc]\x[84]\x[80]\x[80]\x[80]\x[80]"	4000000		6	fc:84:80:80:80:80	1
2.2	Last possible sequence of certain length
2.2.1 y "\x[7f]"			7f		1	7f	1
2.2.2 y "\x[df]\x[bf]"			7ff		2	df:bf	1
# The ffff is illegal unless UTF8_ALLOW_FFFF
2.2.3 n "\x[ef]\x[bf]\x[bf]"			ffff		3	ef:bf:bf	1	character 0xffff
2.2.4 y "\x[f7]\x[bf]\x[bf]\x[bf]"			1fffff		4	f7:bf:bf:bf	1
2.2.5 y "\x[fb]\x[bf]\x[bf]\x[bf]\x[bf]"			3ffffff		5	fb:bf:bf:bf:bf	1
2.2.6 y "\x[fd]\x[bf]\x[bf]\x[bf]\x[bf]\x[bf]"		7fffffff	6	fd:bf:bf:bf:bf:bf	1
2.3	Other boundary conditions
2.3.1 y "\x[ed]\x[9f]\x[bf]"		d7ff		3	ed:9f:bf	1
2.3.2 y "\x[ee]\x[80]\x[80]"		e000		3	ee:80:80	1
2.3.3 y "\x[ef]\x[bf]\x[bd]"			fffd		3	ef:bf:bd	1
2.3.4 y "\x[f4]\x[8f]\x[bf]\x[bf]"		10ffff		4	f4:8f:bf:bf	1
2.3.5 y "\x[f4]\x[90]\x[80]\x[80]"		110000		4	f4:90:80:80	1
3	Malformed sequences
3.1	Unexpected continuation bytes
3.1.1 n "\x[80]"			-		1	80	-	unexpected continuation byte 0x80
3.1.2 n "\x[bf]"			-		1	bf	-	unexpected continuation byte 0xbf
3.1.3 n "\x[80]\x[bf]"			-		2	80:bf	-	unexpected continuation byte 0x80
3.1.4 n "\x[80]\x[bf]\x[80]"		-		3	80:bf:80	-	unexpected continuation byte 0x80
3.1.5 n "\x[80]\x[bf]\x[80]\x[bf]"		-		4	80:bf:80:bf	-	unexpected continuation byte 0x80
3.1.6 n "\x[80]\x[bf]\x[80]\x[bf]\x[80]"	-		5	80:bf:80:bf:80	-	unexpected continuation byte 0x80
3.1.7 n "\x[80]\x[bf]\x[80]\x[bf]\x[80]\x[bf]"	-		6	80:bf:80:bf:80:bf	-	unexpected continuation byte 0x80
3.1.8 n "\x[80]\x[bf]\x[80]\x[bf]\x[80]\x[bf]\x[80]"	-		7	80:bf:80:bf:80:bf:80	-	unexpected continuation byte 0x80
3.1.9 n "\x[80]\x[81]\x[82]\x[83]\x[84]\x[85]\x[86]\x[87]\x[88]\x[89]\x[8a]\x[8b]\x[8c]\x[8d]\x[8e]\x[8f]\x[90]\x[91]\x[92]\x[93]\x[94]\x[95]\x[96]\x[97]\x[98]\x[99]\x[9a]\x[9b]\x[9c]\x[9d]\x[9e]\x[9f]\x[a0]\x[a1]\x[a2]\x[a3]\x[a4]\x[a5]\x[a6]\x[a7]\x[a8]\x[a9]\x[aa]\x[ab]\x[ac]\x[ad]\x[ae]\x[af]\x[b0]\x[b1]\x[b2]\x[b3]\x[b4]\x[b5]\x[b6]\x[b7]\x[b8]\x[b9]\x[ba]\x[bb]\x[bc]\x[bd]\x[be]\x[bf]"				-	64	80:81:82:83:84:85:86:87:88:89:8a:8b:8c:8d:8e:8f:90:91:92:93:94:95:96:97:98:99:9a:9b:9c:9d:9e:9f:a0:a1:a2:a3:a4:a5:a6:a7:a8:a9:aa:ab:ac:ad:ae:af:b0:b1:b2:b3:b4:b5:b6:b7:b8:b9:ba:bb:bc:bd:be:bf	-	unexpected continuation byte 0x80
3.2	Lonely start characters
3.2.1 n "\x[c0] \x[c1] \x[c2] \x[c3] \x[c4] \x[c5] \x[c6] \x[c7] \x[c8] \x[c9] \x[ca] \x[cb] \x[cc] \x[cd] \x[ce] \x[cf] \x[d0] \x[d1] \x[d2] \x[d3] \x[d4] \x[d5] \x[d6] \x[d7] \x[d8] \x[d9] \x[da] \x[db] \x[dc] \x[dd] \x[de] \x[df] "	-	64 	c0:20:c1:20:c2:20:c3:20:c4:20:c5:20:c6:20:c7:20:c8:20:c9:20:ca:20:cb:20:cc:20:cd:20:ce:20:cf:20:d0:20:d1:20:d2:20:d3:20:d4:20:d5:20:d6:20:d7:20:d8:20:d9:20:da:20:db:20:dc:20:dd:20:de:20:df:20	-	unexpected non-continuation byte 0x20 after start byte 0xc0
3.2.2 n "\x[e0] \x[e1] \x[e2] \x[e3] \x[e4] \x[e5] \x[e6] \x[e7] \x[e8] \x[e9] \x[ea] \x[eb] \x[ec] \x[ed] \x[ee] \x[ef] "	-	32	e0:20:e1:20:e2:20:e3:20:e4:20:e5:20:e6:20:e7:20:e8:20:e9:20:ea:20:eb:20:ec:20:ed:20:ee:20:ef:20	-	unexpected non-continuation byte 0x20 after start byte 0xe0
3.2.3 n "\x[f0] \x[f1] \x[f2] \x[f3] \x[f4] \x[f5] \x[f6] \x[f7] "	-	16	f0:20:f1:20:f2:20:f3:20:f4:20:f5:20:f6:20:f7:20	-	unexpected non-continuation byte 0x20 after start byte 0xf0
3.2.4 n "\x[f8] \x[f9] \x[fa] \x[fb] "		-	8	f8:20:f9:20:fa:20:fb:20	-	unexpected non-continuation byte 0x20 after start byte 0xf8
3.2.5 n "\x[fc] \x[fd] "			-	4	fc:20:fd:20	-	unexpected non-continuation byte 0x20 after start byte 0xfc
3.3	Sequences with last continuation byte missing
3.3.1 n "\x[c0]"			-	1	c0	-	1 byte, need 2
3.3.2 n "\x[e0]\x[80]"			-	2	e0:80	-	2 bytes, need 3
3.3.3 n "\x[f0]\x[80]\x[80]"		-	3	f0:80:80	-	3 bytes, need 4
3.3.4 n "\x[f8]\x[80]\x[80]\x[80]"		-	4	f8:80:80:80	-	4 bytes, need 5
3.3.5 n "\x[fc]\x[80]\x[80]\x[80]\x[80]"	-	5	fc:80:80:80:80	-	5 bytes, need 6
3.3.6 n "\x[df]"			-	1	df	-	1 byte, need 2
3.3.7 n "\x[ef]\x[bf]"			-	2	ef:bf	-	2 bytes, need 3
3.3.8 n "\x[f7]\x[bf]\x[bf]"			-	3	f7:bf:bf	-	3 bytes, need 4
3.3.9 n "\x[fb]\x[bf]\x[bf]\x[bf]"			-	4	fb:bf:bf:bf	-	4 bytes, need 5
3.3.10 n "\x[fd]\x[bf]\x[bf]\x[bf]\x[bf]"		-	5	fd:bf:bf:bf:bf	-	5 bytes, need 6
3.4	Concatenation of incomplete sequences
3.4.1 n "\x[c0]\x[e0]\x[80]\x[f0]\x[80]\x[80]\x[f8]\x[80]\x[80]\x[80]\x[fc]\x[80]\x[80]\x[80]\x[80]\x[df]\x[ef]\x[bf]\x[f7]\x[bf]\x[bf]\x[fb]\x[bf]\x[bf]\x[bf]\x[fd]\x[bf]\x[bf]\x[bf]\x[bf]"	-	30	c0:e0:80:f0:80:80:f8:80:80:80:fc:80:80:80:80:df:ef:bf:f7:bf:bf:fb:bf:bf:bf:fd:bf:bf:bf:bf	-	unexpected non-continuation byte 0xe0 after start byte 0xc0
3.5	Impossible bytes
3.5.1 n "\x[fe]"			-	1	fe	-	byte 0xfe
3.5.2 n "\x[ff]"			-	1	ff	-	byte 0xff
3.5.3 n "\x[fe]\x[fe]\x[ff]\x[ff]"			-	4	fe:fe:ff:ff	-	byte 0xfe
4	Overlong sequences
4.1	Examples of an overlong ASCII character
4.1.1 n "\x[c0]\x[af]"			-	2	c0:af	-	2 bytes, need 1
4.1.2 n "\x[e0]\x[80]\x[af]"		-	3	e0:80:af	-	3 bytes, need 1
4.1.3 n "\x[f0]\x[80]\x[80]\x[af]"		-	4	f0:80:80:af	-	4 bytes, need 1
4.1.4 n "\x[f8]\x[80]\x[80]\x[80]\x[af]"	-	5	f8:80:80:80:af	-	5 bytes, need 1
4.1.5 n "\x[fc]\x[80]\x[80]\x[80]\x[80]\x[af]"	-	6	fc:80:80:80:80:af	-	6 bytes, need 1
4.2	Maximum overlong sequences
4.2.1 n "\x[c1]\x[bf]"			-	2	c1:bf	-	2 bytes, need 1
4.2.2 n "\x[e0]\x[9f]\x[bf]"		-	3	e0:9f:bf	-	3 bytes, need 2
4.2.3 n "\x[f0]\x[8f]\x[bf]\x[bf]"		-	4	f0:8f:bf:bf	-	4 bytes, need 3
4.2.4 n "\x[f8]\x[87]\x[bf]\x[bf]\x[bf]"		-	5	f8:87:bf:bf:bf	-	5 bytes, need 4
4.2.5 n "\x[fc]\x[83]\x[bf]\x[bf]\x[bf]\x[bf]"		-	6	fc:83:bf:bf:bf:bf	-	6 bytes, need 5
4.3	Overlong representation of the NUL character
4.3.1 n "\x[c0]\x[80]"			-	2	c0:80	-	2 bytes, need 1
4.3.2 n "\x[e0]\x[80]\x[80]"		-	3	e0:80:80	-	3 bytes, need 1
4.3.3 n "\x[f0]\x[80]\x[80]\x[80]"		-	4	f0:80:80:80	-	4 bytes, need 1
4.3.4 n "\x[f8]\x[80]\x[80]\x[80]\x[80]"	-	5	f8:80:80:80:80	-	5 bytes, need 1
4.3.5 n "\x[fc]\x[80]\x[80]\x[80]\x[80]\x[80]"	-	6	fc:80:80:80:80:80	-	6 bytes, need 1
5	Illegal code positions
5.1	Single UTF-16 surrogates
5.1.1 n "\x[ed]\x[a0]\x[80]"		-	3	ed:a0:80	-	UTF-16 surrogate 0xd800
5.1.2 n "\x[ed]\x[ad]\x[bf]"			-	3	ed:ad:bf	-	UTF-16 surrogate 0xdb7f
5.1.3 n "\x[ed]\x[ae]\x[80]"		-	3	ed:ae:80	-	UTF-16 surrogate 0xdb80
5.1.4 n "\x[ed]\x[af]\x[bf]"			-	3	ed:af:bf	-	UTF-16 surrogate 0xdbff
5.1.5 n "\x[ed]\x[b0]\x[80]"		-	3	ed:b0:80	-	UTF-16 surrogate 0xdc00
5.1.6 n "\x[ed]\x[be]\x[80]"		-	3	ed:be:80	-	UTF-16 surrogate 0xdf80
5.1.7 n "\x[ed]\x[bf]\x[bf]"			-	3	ed:bf:bf	-	UTF-16 surrogate 0xdfff
5.2	Paired UTF-16 surrogates
5.2.1 n "\x[ed]\x[a0]\x[80]\x[ed]\x[b0]\x[80]"		-	6	ed:a0:80:ed:b0:80	-	UTF-16 surrogate 0xd800
5.2.2 n "\x[ed]\x[a0]\x[80]\x[ed]\x[bf]\x[bf]"		-	6	ed:a0:80:ed:bf:bf	-	UTF-16 surrogate 0xd800
5.2.3 n "\x[ed]\x[ad]\x[bf]\x[ed]\x[b0]\x[80]"		-	6	ed:ad:bf:ed:b0:80	-	UTF-16 surrogate 0xdb7f
5.2.4 n "\x[ed]\x[ad]\x[bf]\x[ed]\x[bf]\x[bf]"		-	6	ed:ad:bf:ed:bf:bf	-	UTF-16 surrogate 0xdb7f
5.2.5 n "\x[ed]\x[ae]\x[80]\x[ed]\x[b0]\x[80]"		-	6	ed:ae:80:ed:b0:80	-	UTF-16 surrogate 0xdb80
5.2.6 n "\x[ed]\x[ae]\x[80]\x[ed]\x[bf]\x[bf]"		-	6	ed:ae:80:ed:bf:bf	-	UTF-16 surrogate 0xdb80
5.2.7 n "\x[ed]\x[af]\x[bf]\x[ed]\x[b0]\x[80]"		-	6	ed:af:bf:ed:b0:80	-	UTF-16 surrogate 0xdbff
5.2.8 n "\x[ed]\x[af]\x[bf]\x[ed]\x[bf]\x[bf]"		-	6	ed:af:bf:ed:bf:bf	-	UTF-16 surrogate 0xdbff
5.3	Other illegal code positions
5.3.1 n "\x[ef]\x[bf]\x[be]"			-	3	ef:bf:be	-	byte order mark 0xfffe
# The ffff is illegal unless UTF8_ALLOW_FFFF
5.3.2 n "\x[ef]\x[bf]\x[bf]"			-	3	ef:bf:bf	-	character 0xffff
__EOMK__

# 104..181
do
    my $id

    my $x_warn
    local $^WARN_HOOK = sub (@< @_)
        print: $^STDOUT, "# $id: " . @_[0]->{?description} . "\n"
        $x_warn = @_[0]->{?description}
    

    sub moan
        print: $^STDOUT, "$id: $((join: ' ',@_))"
    

    sub warn_unpack_U
        $x_warn = ''
        my @null = @:  unpack: 'U0U*', @_[0] 
        return $x_warn
    

    for ( @MK)
        if (m/^(?:\d+(?:\.\d+)?)\s/ || m/^#/) {
        # print "# $_\n";
        }elsif (m/^(\d+\.\d+\.\d+[bu]?)\s+([yn])\s+"(.+)"\s+([0-9a-f]{1,8}|-)\s+(\d+)\s+([0-9a-f]{2}(?::[0-9a-f]{2})*)(?:\s+((?:\d+|-)(?:\s+(.+))?))?$/)
            $id = $1
            my (@: $okay, $bytes, $Unicode, $byteslen, $hex, $charslen, $experr) =
                @: $2, $3, $4, $5, $6, $7, $8
            my @hex = split: m/:/, $hex
            unless ((nelems @hex) == $byteslen)
                my $nhex = (nelems @hex)
                moan: "amount of hex ($nhex) not equal to byteslen ($byteslen)\n"
            
            do
                use bytes
                my $bytesbyteslen = length: $bytes
                unless ($bytesbyteslen == $byteslen)
                    moan: "bytes length() ($bytesbyteslen) not equal to $byteslen\n"
                
            
            my $warn = warn_unpack_U: $bytes
            if ($okay eq 'y')
                if ($warn)
                    moan: "unpack('U0U*') false negative\n"
                    print: $^STDOUT, "not "
                
            elsif ($okay eq 'n')
                if (not $warn || ($experr ne '' && $warn !~ m/$experr/))
                    moan: "unpack('U0U*') false positive\n"
                    print: $^STDOUT, "not "
                
            
            print: $^STDOUT, "ok $test # $id $okay\n"
            $test++
        else
            moan: "unknown format\n"
        
    

