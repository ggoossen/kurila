#!./perl
#
# Contributed by Graham Barr <Graham.Barr@tiuk.ti.com>
#
# So far there are tests for the following prototypes.
# none, () ($) ($@) ($%) ($;$) (&) (&\@) (&@) (%) (\%) (\@)
#
# It is impossible to test every prototype that can be specified, but
# we should test as many as we can.
#

use strict;

print "1..116\n";

my $i = 1;

sub testing (&$) {
    my $p = prototype(shift);
    my $c = shift;
    my $what = defined $c ? '(' . $p . ')' : 'no prototype';   
    print '#' x 25,"\n";
    print '# Testing ',$what,"\n";
    print '#' x 25,"\n";
    print "not "
	if((defined($p) && defined($c) && $p ne $c)
	   || (defined($p) != defined($c)));
    printf "ok \%d\n",$i++;
}

@_ = @( < qw(a b c d) );
my @array;
my %hash;

##
##
##

testing \&no_proto, undef;

sub no_proto {
    print "# \@_ = (",join(",", @(< @_)),")\n";
    scalar(nelems @_)
}

print "not " unless 0 == no_proto();
printf "ok \%d\n",$i++;

print "not " unless 1 == no_proto(5);
printf "ok \%d\n",$i++;

print "not " unless 4 == &no_proto;
printf "ok \%d\n",$i++;

print "not " unless 1 == no_proto +6;
printf "ok \%d\n",$i++;

print "not " unless 4 == no_proto(< @_);
printf "ok \%d\n",$i++;

##
##
##


testing \&no_args, '';

sub no_args () {
    print "# \@_ = (",join(",", @(< @_)),")\n";
    scalar(nelems @_)
}

print "not " unless 0 == no_args();
printf "ok \%d\n",$i++;

print "not " unless 0 == no_args;
printf "ok \%d\n",$i++;

print "not " unless 5 == no_args +5;
printf "ok \%d\n",$i++;

print "not " unless 4 == &no_args;
printf "ok \%d\n",$i++;

print "not " unless 2 == &no_args(1,2);
printf "ok \%d\n",$i++;

eval "no_args(1)";
print "not " unless $@;
printf "ok \%d\n",$i++;

##
##
##

testing \&one_args, '$';

sub one_args ($) {
    print "# \@_ = (",join(",", @(< @_)),")\n";
    scalar(nelems @_)
}

print "not " unless 1 == one_args(1);
printf "ok \%d\n",$i++;

print "not " unless 1 == one_args +5;
printf "ok \%d\n",$i++;

print "not " unless 4 == &one_args;
printf "ok \%d\n",$i++;

print "not " unless 2 == &one_args(1,2);
printf "ok \%d\n",$i++;

eval "one_args(1,2)";
print "not " unless $@;
printf "ok \%d\n",$i++;

eval "one_args()";
print "not " unless $@;
printf "ok \%d\n",$i++;

sub one_a_args ($) {
    print "# \@_ = (",join(",", @(< @_)),")\n";
    print "not " unless (nelems @_) == 1 && @_[0] == 4;
    printf "ok \%d\n",$i++;
}

one_a_args((nelems @_));

##
##
##

testing \&over_one_args, '$@';

sub over_one_args ($@) {
    print "# \@_ = (",join(",", @(< @_)),")\n";
    scalar(nelems @_)
}

print "not " unless 1 == over_one_args(1);
printf "ok \%d\n",$i++;

print "not " unless 2 == over_one_args(1,2);
printf "ok \%d\n",$i++;

print "not " unless 1 == over_one_args +5;
printf "ok \%d\n",$i++;

print "not " unless 4 == &over_one_args;
printf "ok \%d\n",$i++;

print "not " unless 2 == &over_one_args(1,2);
printf "ok \%d\n",$i++;

print "not " unless 5 == &over_one_args(1,< @_);
printf "ok \%d\n",$i++;

eval "over_one_args()";
print "not " unless $@;
printf "ok \%d\n",$i++;

sub over_one_a_args ($@) {
    print "# \@_ = (",join(",", @(< @_)),")\n";
    print "not " unless (nelems @_) +>= 1 && @_[0] == 4;
    printf "ok \%d\n",$i++;
}

over_one_a_args((nelems @_));
over_one_a_args((nelems @_),1);
over_one_a_args((nelems @_),1,2);
over_one_a_args((nelems @_),< @_);

##
##
##

testing \&one_or_two, '$;$';

sub one_or_two ($;$) {
    print "# \@_ = (",join(",", @(< @_)),")\n";
    scalar(nelems @_)
}

print "not " unless 1 == one_or_two(1);
printf "ok \%d\n",$i++;

print "not " unless 2 == one_or_two(1,3);
printf "ok \%d\n",$i++;

print "not " unless 1 == one_or_two +5;
printf "ok \%d\n",$i++;

print "not " unless 4 == &one_or_two;
printf "ok \%d\n",$i++;

print "not " unless 3 == &one_or_two(1,2,3);
printf "ok \%d\n",$i++;

print "not " unless 5 == &one_or_two(1,< @_);
printf "ok \%d\n",$i++;

eval "one_or_two()";
print "not " unless $@;
printf "ok \%d\n",$i++;

eval "one_or_two(1,2,3)";
print "not " unless $@;
printf "ok \%d\n",$i++;

sub one_or_two_a ($;$) {
    print "# \@_ = (",join(",", @(< @_)),")\n";
    print "not " unless (nelems @_) +>= 1 && @_[0] == 4;
    printf "ok \%d\n",$i++;
}

one_or_two_a((nelems @_));
one_or_two_a((nelems @_),1);
one_or_two_a((nelems @_),nelems @_);

##
##
##

testing \&a_sub, '&';

sub a_sub (&) {
    print "# \@_ = (",join(",", @(< map {dump::view($_)} @( < @_))),")\n";
    &{@_[0]};
}

sub tmp_sub_1 { printf "ok \%d\n",$i++ }

a_sub { printf "ok \%d\n",$i++ };
a_sub \&tmp_sub_1;

@array = @( \&tmp_sub_1 );
eval 'a_sub @array';
print "not " unless $@;
printf "ok \%d\n",$i++;

##
##
##

testing \&sub_aref, '&\@';

sub sub_aref (&\@) {
    print "# \@_ = (",join(",", @(< map {dump::view($_)} @( < @_))),")\n";
    my($sub,$array) = < @_;
    print "not " unless (nelems @_) == 2 && (nelems @{$array}) == 4;
    print < map { &{$sub}($_) } @( < @{$array}
)}

@array = @( <qw(O K)," ", $i++);
sub_aref { lc shift } @array;
print "\n";

##
##
##

testing \&sub_array, '&@';

sub sub_array (&@) {
    print "# \@_ = (",join(",", @(< map {dump::view($_)} @( < @_))),")\n";
    print "not " unless (nelems @_) == 5;
    my $sub = shift;
    print < map { &{$sub}($_) } @( < @_)
}

@array = @( <qw(O K)," ", $i++);
sub_array { lc shift } < @array;
sub_array { lc shift } ('O', 'K', ' ', $i++);
print "\n";
##
##
##

testing \&a_hash_ref, '\%';

sub a_hash_ref (\%) {
    print "# \@_ = (",join(",", @(< map {dump::view($_)} @( < @_))),")\n";
    print "not " unless ref(@_[0]) && @_[0]->{'a'};
    printf "ok \%d\n",$i++;
    @_[0]->{'b'} = 2;
}

%hash = %( a => 1);
a_hash_ref %hash;
print "not " unless %hash{'b'} == 2;
printf "ok \%d\n",$i++;

##
##
##

testing \&array_ref_plus, '\@@';

sub array_ref_plus (\@@) {
    print "# \@_ = (",join(",", @(< map {dump::view($_)} @( < @_))),")\n";
    print "not " unless (nelems @_) == 2 && ref(@_[0]) && 1 == nelems @{@_[0]} && @_[1] eq 'x';
    printf "ok \%d\n",$i++;
    @{@_[0]} = @( <qw(ok)," ",$i++,"\n");
}

@array = @('a');
{ my @more = @('x');
  array_ref_plus @array, < @more; }
print "not " unless (nelems @array) == 4;
print < @array;

my $p;
print "not " if defined prototype('CORE::print');
print "ok ", $i++, "\n";

print "not " if defined prototype('CORE::system');
print "ok ", $i++, "\n";

print "# CORE::open => ($p)\nnot " if ($p = prototype('CORE::open')) ne '*;$@';
print "ok ", $i++, "\n";

print "# CORE:Foo => ($p), \$@ => `$@'\nnot " 
    if defined ($p = try { prototype('CORE::Foo') or 1 }) or $@->message !~ m/^Can't find an opnumber/;
print "ok ", $i++, "\n";

# correctly note too-short parameter lists that don't end with '$',
#  a possible regression.

sub foo1 ($\@) { 1 };
eval q{ foo1 "s" };
print "not " unless $@->message =~ m/^Not enough/;
print "ok ", $i++, "\n";

sub foo2 ($\%) { 1 };
eval q{ foo2 "s" };
print "not " unless $@->message =~ m/^Not enough/;
print "ok ", $i++, "\n";

# test if the (*) prototype allows barewords, constants, scalar expressions,
# globs and globrefs (just as CORE::open() does), all under stricture
sub star (*&) { &{@_[1]} }
sub star2 (**&) { &{@_[2]} }
sub BAR { "quux" }
sub Bar::BAZ { "quuz" }
my $star = 'FOO';
star 'FOO', sub {
    print "not " unless @_[0] eq 'FOO';
    print "ok $i - star FOO\n";
}; $i++;
star('FOO', sub {
	print "not " unless @_[0] eq 'FOO';
	print "ok $i - star(FOO)\n";
    }); $i++;
star "FOO", sub {
    print "not " unless @_[0] eq 'FOO';
    print qq/ok $i - star "FOO"\n/;
}; $i++;
star("FOO", sub {
	print "not " unless @_[0] eq 'FOO';
	print qq/ok $i - star("FOO")\n/;
    }); $i++;
star $star, sub {
    print "not " unless @_[0] eq 'FOO';
    print "ok $i - star \$star\n";
}; $i++;
star($star, sub {
	print "not " unless @_[0] eq 'FOO';
	print "ok $i - star(\$star)\n";
    }); $i++;
star *FOO, sub {
    print "not " unless @_[0] \== \*FOO;
    print "ok $i - star *FOO\n";
}; $i++;
star(*FOO, sub {
	print "not " unless @_[0] \== \*FOO;
	print "ok $i - star(*FOO)\n";
    }); $i++;
star \*FOO, sub {
    print "not " unless @_[0] \== \*FOO;
    print "ok $i - star \\*FOO\n";
}; $i++;
star(\*FOO, sub {
	print "not " unless @_[0] \== \*FOO;
	print "ok $i - star(\\*FOO)\n";
    }); $i++;
star2(Bar::BAZ, 'FOO', sub {
	print "not " unless @_[0] eq 'Bar::BAZ' and @_[1] eq 'FOO';
	print "ok $i - star2(Bar::BAZ, FOO)\n"
    }); $i++;
star2 BAR(), 'FOO', sub {
    print "not " unless @_[0] eq 'quux' and @_[1] eq 'FOO';
    print "ok $i - star2 BAR(), FOO\n"
}; $i++;
star2('FOO', BAR(), sub {
	print "not " unless @_[0] eq 'FOO' and @_[1] eq 'quux';
	print "ok $i - star2(FOO, BAR())\n";
    }); $i++;
star2 "FOO", "BAR", sub {
    print "not " unless @_[0] eq 'FOO' and @_[1] eq 'BAR';
    print qq/ok $i - star2 "FOO", "BAR"\n/;
}; $i++;
star2("FOO", "BAR", sub {
	print "not " unless @_[0] eq 'FOO' and @_[1] eq 'BAR';
	print qq/ok $i - star2("FOO", "BAR")\n/;
    }); $i++;
star2 $star, $star, sub {
    print "not " unless @_[0] eq 'FOO' and @_[1] eq 'FOO';
    print "ok $i - star2 \$star, \$star\n";
}; $i++;
star2($star, $star, sub {
	print "not " unless @_[0] eq 'FOO' and @_[1] eq 'FOO';
	print "ok $i - star2(\$star, \$star)\n";
    }); $i++;
star2 *FOO, *BAR, sub {
    print "not " unless @_[0] \== \*FOO and @_[1] \== \*BAR;
    print "ok $i - star2 *FOO, *BAR\n";
}; $i++;
star2(*FOO, *BAR, sub {
	print "not " unless @_[0] \== \*FOO and @_[1] \== \*BAR;
	print "ok $i - star2(*FOO, *BAR)\n";
    }); $i++;
star2 \*FOO, \*BAR, sub {
    no strict 'refs';
    print "not " unless @_[0] \== \*{Symbol::fetch_glob('FOO')} and @_[1] \== \*{Symbol::fetch_glob('BAR')};
    print "ok $i - star2 \*FOO, \*BAR\n";
}; $i++;
star2(\*FOO, \*BAR, sub {
	no strict 'refs';
	print "not " unless @_[0] \== \*{Symbol::fetch_glob('FOO')} and @_[1] \== \*{Symbol::fetch_glob('BAR')};
	print "ok $i - star2(\*FOO, \*BAR)\n";
    }); $i++;

# test scalarref prototype
sub sreftest (\$$) {
    print "not " unless ref @_[0];
    print "ok @_[1] - sreftest\n";
}
{
    our (%helem, @aelem);
    sreftest my $sref, $i++;
    sreftest(%helem{$i}, $i++);
    sreftest @aelem[0], $i++;
}

# test prototypes when they are evaled and there is a syntax error
# Byacc generates the string "syntax error".  Bison gives the
# string "parse error".
#
for my $p (@( "", < qw{ () ($) ($@) ($%) ($;$) (&) (&\@) (&@) (%) (\%) (\@) }) ) {
  no warnings 'prototype';
  my $eval = "sub evaled_subroutine $p \{ &void *; \}";
  eval $eval;
  print "# eval[$eval]\nnot " unless $@ && $@->message =~ m/(parse|syntax) error/i;
  print "ok ", $i++, "\n";
}

# Not $$;$;$
print "not " unless prototype "CORE::substr" eq '$$;$$';
print "ok ", $i++, "\n";

# recv takes a scalar reference for its second argument
print "not " unless prototype "CORE::recv" eq '*\$$$';
print "ok ", $i++, "\n";

{
    my $myvar;
    my @myarray;
    my %myhash;
    sub mysub { die "not calling mysub I hope\n" }
    local *myglob;

    sub myref (\[$@%&*]) { return dump::view(@_[0]) }

    print "not " unless myref($myvar)   =~ m/^SCALAR\(/;
    print "ok ", $i++, "\n";
    print "not " unless myref(@myarray) =~ m/^ARRAY\(/;
    print "ok ", $i++, "\n";
    print "not " unless myref(%myhash)  =~ m/^HASH\(/;
    print "ok ", $i++, "\n";
    print "not ok", $i++," # TODO\n";
#    print "not " unless myref(\&mysub)   =~ m/^CODE\(/;
#    print "ok ", $i++, "\n";
    print "not " unless myref(*myglob)  =~ m/^GLOB\(/;
    print "ok ", $i++, "\n";

    eval q/sub multi4 ($\[%]) { 1 } multi4 1, &mysub;/;
    print "not "
	unless $@->message =~ m/Type of arg 2 to main::multi4 must be one of \[%\] /;
    print "ok ", $i++, "\n";
    eval q/sub multi5 (\[$@]$) { 1 } multi5 *myglob;/;
    print "not "
	unless $@->message =~ m/Type of arg 1 to main::multi5 must be one of \[\$\@\] /
	    && $@->message =~ m/Not enough arguments/;
    print "ok ", $i++, "\n";
}

# check that obviously bad prototypes are getting warnings
{
  use warnings 'syntax';
  my $warn = "";
  local $^WARN_HOOK = sub { $warn .= @_[0]->{description} . "\n" };
  
  eval 'sub badproto (@bar) { 1; }';
  print "not " unless $warn =~ m/Illegal character in prototype for main::badproto : \@bar/;
  print "ok ", $i++, "\n";

  eval 'sub badproto2 (bar) { 1; }';
  print "not " unless $warn =~ m/Illegal character in prototype for main::badproto2 : bar/;
  print "ok ", $i++, "\n";
  
  eval 'sub badproto3 (&$bar$@) { 1; }';
  print "not " unless $warn =~ m/Illegal character in prototype for main::badproto3 : &\$bar\$\@/;
  print "ok ", $i++, "\n";
  
  eval 'sub badproto4 (@ $b ar) { 1; }';
  print "not " unless $warn =~ m/Illegal character in prototype for main::badproto4 : \@\$bar/;
  print "ok ", $i++, "\n";
}

# make sure whitespace in prototypes works
eval "sub good (\$\t\$\n\$) \{ 1; \}";
print "not " if $@;
print "ok ", $i++, "\n";
