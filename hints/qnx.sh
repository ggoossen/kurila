#----------------------------------------------------------------
# QNX hints
#
# As of perl5.003_09, perl5 will compile without errors
# and pass almost all the tests in the test suite. The remaining
# failures have been identified as bugs in the Watcom libraries
# which I hope will be fixed in the near future.
#
# As with many unix ports, this one depends on a few "standard"
# unix utilities which are not necessarily standard for QNX.
#
# /bin/sh  This is used heavily by Configure and then by
#          perl itself. QNX's version is fine, but Configure
#          will choke on the 16-bit version, so if you are
#          running QNX 4.22, link /bin/sh to /bin32/ksh
# ar       This is the standard unix library builder.
#          We use wlib. With Watcom 10.6, when wlib is
#          linked as "ar", it behaves like ar and all is
#          fine. Under 9.5, a cover is required. One is
#          included in ../qnx
# nm       This is used (optionally) by configure to list
#          the contents of libraries. I will generate
#          a cover function on the fly in the UU directory.
# cpp      Configure and perl need a way to invoke a C
#          preprocessor. I have created a simple cover
#          for cc which does the right thing. Without this,
#          Configure will create it's own wrapper which works,
#          but it doesn't handle some of the command line arguments
#          that perl will throw at it.
# make     You really need GNU make to compile this. GNU make
#          ships by default with QNX 4.23, but you can get it
#          from quics for earlier versions.
#----------------------------------------------------------------
# Outstanding Issues:
#   lib/posix.t test fails on test 17 because acos(1) != 0.
#      Watcom promises to fix this in next release.
#   lib/io_udp.t test hangs because of a bug in getsockname().
#      Fixed in latest BETA socket3r.lib
#   If there is a softlink in your path, Findbin will fail.
#      This is a documented feature of getpwd().
#   There is currently no support for dynamically linked
#      libraries.
#----------------------------------------------------------------
# At present, all QNX systems are equivalent architectures,
# so it might be reasonable to call archname=qnx rather than
# making an unnecessary distinction between AT-qnx and PCI-qnx,
# for example.
#----------------------------------------------------------------
# These hints were submitted by:
#   Norton T. Allen
#   Harvard University Atmospheric Research Project
#   allen@huarp.harvard.edu
#
# If you have suggestions or changes, please let me know.
#----------------------------------------------------------------

#----------------------------------------------------------------
# QNX doesn't come with a csh and the ports of tcsh I've used
# don't work reliably:
#----------------------------------------------------------------
csh=''
d_csh='undef'
full_csh=''

#----------------------------------------------------------------
# difftime is implemented as a preprocessor macro, so it doesn't show
# up in the libraries:
#----------------------------------------------------------------
d_difftime='define'

#----------------------------------------------------------------
# strtod is in the math library, but we can't tell Configure
# about the math library or it will confuse the linker
#----------------------------------------------------------------
d_strtod='define'

#----------------------------------------------------------------
# The following exist in the libraries, but there are no
# prototypes available:
#----------------------------------------------------------------
d_setregid='undef'
d_setreuid='undef'
d_setlinebuf='undef'
d_truncate='undef'
d_getpgid='undef'

lib_ext='3r.lib'
libc='/usr/lib/clib3r.lib'

#----------------------------------------------------------------
# ccflags:
# I like to turn the warnings up high, but a few common
# constructs make a lot of noise, so I turn those warnings off.
# A few still remain...
#
# HIDEMYMALLOC is necessary if using mymalloc since it is very
# tricky (though not impossible) to totally replace the watcom
# malloc/free set.
#
# unix.h is required as a general rule for unixy applications.
#----------------------------------------------------------------
ccflags='-DHIDEMYMALLOC -mf -w4 -Wc,-wcd=202 -Wc,-wcd=203 -Wc,-wcd=302 -Wc,-fi=unix.h'

#----------------------------------------------------------------
# ldflags:
# If you want debugging information, you must specify -g on the
# link as well as the compile. If optimize != -g, you should
# remove this.
#----------------------------------------------------------------
ldflags="-g"

so='none'
selecttype='fd_set *'

#----------------------------------------------------------------
# Add -lunix to list of libs. This is needed mainly so the nm
# search will find funcs in the unix lib. Including unix.h should
# automatically include the library without -l.
#----------------------------------------------------------------
libswanted="$libswanted unix"

if [ -z "`which ar 2>/dev/null`" ]; then
  cat <<-'EOF' >&4
	I don't see an 'ar', so I'm guessing you are running
	Watcom 9.5 or earlier. You may want to install the ar
	cover found in the qnx subdirectory of this distribution.
	It might reasonably be placed in /usr/local/bin.

	EOF
fi
#----------------------------------------------------------------
# Here is a nm script which fixes up wlib's output to look
# something like nm's, at least enough so that Configure can
# use it.
#----------------------------------------------------------------
if [ -z "`which nm 2>/dev/null`" ]; then
  cat <<-EOF
	Creating a quick-and-dirty nm cover for	Configure to use:

	EOF
  cat >../UU/nm <<-'EOF'
	#! /bin/sh
	#__USAGE
	#%C	<lib> [<lib> ...]
	#	Designed to mimic Unix's nm utility to list
	#	defined symbols in a library
	for i in $*; do wlib $i; done |
	  awk '
	    /^  / {
	      for (i = 1; i <= NF; i++) {
	        sub("_$", "", $i)
	        print "000000  T " $i
	      }
	    }'
	EOF
  chmod +x ../UU/nm
fi

cppstdin=`which cpp 2>/dev/null`
if [ -n "$cppstdin" ]; then
  cat <<-EOF >&4
	I found a cpp at $cppstdin and will assume it is a good
	thing to use. If this proves to be false, there is a
	thin cover for cpp in the qnx subdirectory of this
	distribution which you could move into your path.
	EOF
  cpprun="$cppstdin"
else
  cat <<-EOF >&4
	
	There is a cpp cover in the qnx subdirectory of this
	distribution which works a little better than the
	Configure default. You may wish to copy it to
	/usr/local/bin or some other suitable location.
	EOF
fi	
