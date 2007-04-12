

#
# The reason this does not use a Test module is that
# they mess up test numbers between threads
#
# And even when that will be fixed, this is a basic
# test and should not rely on shared variables
#
# This will test the basic API, it will not use any coderefs
# as they are more advanced
#
#########################


BEGIN {
    chdir 't' if -d 't';
    @INC = '../lib';
    require Config; import Config;
    unless ($Config{'useithreads'}) {
	print "1..0 # Skip: no useithreads\n";
 	exit 0;	
    }
}

use ExtUtils::testlib;
use strict;
BEGIN { $| = 1; print "1..15\n" };
use threads;



print "ok 1\n";


#########################




sub ok {	
    my ($id, $ok, $name) = @_;

    # You have to do it this way or VMS will get confused.
    print $ok ? "ok $id - $name\n" : "not ok $id - $name\n";

    printf "# Failed test at line %d\n", (caller)[2] unless $ok;

    return $ok;
}



sub test1 {
	ok(2,'bar' eq $_[0],"Test that argument passing works");
}
threads->create('test1','bar')->join();

sub test2 {
	ok(3,'bar' eq $_[0]->[0]->{foo},"Test that passing arguments as references work");
}

threads->create('test2',[{foo => 'bar'}])->join();


#test execuion of normal sub
sub test3 { ok(4,shift() == 1,"Test a normal sub") }
threads->create('test3',1)->join();


#check Config
ok(5, 1 == $threads::threads,"Check that threads::threads is true");

#test trying to detach thread

sub test4 { ok(6,1,"Detach test"); rmdir "thrsem" }

# Just a sleep() would not guarantee that we sleep and will not
# wake up before the just created thread finishes.  Instead, let's
# use the filesystem as a semaphore.  Creating a directory and removing
# it should be a reasonably atomic operation even over NFS. 
# Also, we do not want to depend here on shared variables.

mkdir "thrsem", 0700;

my $thread1 = threads->create('test4');

$thread1->detach();
sleep 1 while -d "thrsem";
ok(7,1,"Detach test");



sub test5 {
	threads->create('test6')->join();
	ok(9,1,"Nested thread test");
}

sub test6 {
	ok(8,1,"Nested thread test");
}

threads->create('test5')->join();

sub test7 {
	my $self = threads->self();
	ok(10, $self->tid == 7, "Wanted 7, got ".$self->tid);
	ok(11, threads->tid() == 7, "Wanted 7, got ".threads->tid());
}

threads->create('test7')->join;

sub test8 {
	my $self = threads->self();
	ok(12, $self->tid == 8, "Wanted 8, got ".$self->tid);
	ok(13, threads->tid() == 8, "Wanted 8, got ".threads->tid());
}

threads->create('test8')->join;


#check support for threads->self() in main thread
ok(14, 0 == threads->self->tid(),"Check so that tid for threads work for main thread");
ok(15, 0 == threads->tid(),"Check so that tid for threads work for main thread");

END {
    1 while rmdir "thrsem";
}

1;
