#
# Makefile to build perl on Windowns NT using DMAKE.
# Supported compilers:
#	Visual C++ 2.0 thro 5.0
#	Borland C++ 5.02
#	Mingw32-0.1.4 with gcc-2.7.2
#
# This is set up to build a perl.exe that runs off a shared library
# (perl.dll).  Also makes individual DLLs for the XS extensions.
#

#
# Set these to wherever you want "nmake install" to put your
# newly built perl.
INST_DRV	*= c:
INST_TOP	*= $(INST_DRV)\perl

# Comment this out if you DON'T want your perl installation to be versioned.
# This means that the new installation will overwrite any files from the
# old installation at the same INST_TOP location.  Leaving it enabled is
# the safest route, as perl adds the extra version directory to all the
# locations it installs files to.  If you disable it, an alternative
# versioned installation can be obtained by setting INST_TOP above to a
# path that includes an arbitrary version string.
INST_VER	*= \5.00466

#
# uncomment to enable threads-capabilities
#USE_THREADS	*= define

#
# uncomment one
#CCTYPE		*= MSVC20
#CCTYPE		*= MSVC
CCTYPE		*= BORLAND
#CCTYPE		*= GCC

#
# uncomment next line if you want to use the perl object
# Currently, this cannot be enabled if you ask for threads above
#OBJECT		*= -DPERL_OBJECT

#
# uncomment next line if you want debug version of perl (big,slow)
#CFG		*= Debug

#
# if you have the source for des_fcrypt(), uncomment this and make sure the
# file exists (see README.win32).  File should be located at the perl
# top level directory.
#CRYPT_SRC	*= des_fcrypt.c

#
# if you didn't set CRYPT_SRC and if you have des_fcrypt() available in a
# library, uncomment this, and make sure the library exists (see README.win32)
# Specify the full pathname of the library.
#CRYPT_LIB	*= des_fcrypt.lib

#
# set this if you wish to use perl's malloc
# WARNING: Turning this on/off WILL break binary compatibility with extensions
# you may have compiled with/without it.  Be prepared to recompile all extensions
# if you change the default.  Currently, this cannot be enabled if you ask for
# PERL_OBJECT above.
#PERL_MALLOC	*= define

#
# set the install locations of the compiler include/libraries
#
#CCHOME		*= f:\msdev\vc
CCHOME		*= C:\bc5
#CCHOME		*= D:\packages\mingw32
CCINCDIR	*= $(CCHOME)\include
CCLIBDIR	*= $(CCHOME)\lib

#
# set this to point to cmd.exe (only needed if you use some
# alternate shell that doesn't grok cmd.exe style commands)
#SHELL		*= g:\winnt\system32\cmd.exe

#
# set this to your email address (perl will guess a value from
# from your loginname and your hostname, which may not be right)
#EMAIL		*= 

##################### CHANGE THESE ONLY IF YOU MUST #####################

.IF "$(CRYPT_SRC)$(CRYPT_LIB)" == ""
D_CRYPT		= undef
.ELSE
D_CRYPT		= define
CRYPT_FLAG	= -DHAVE_DES_FCRYPT
.ENDIF

.IF "$(OBJECT)" != ""
PERL_MALLOC	!= undef
.ENDIF

PERL_MALLOC	*= undef

USE_THREADS	*= undef

#BUILDOPT	*= -DMULTIPLICITY 
#BUILDOPT	*= -DPERL_GLOBAL_STRUCT -DMULTIPLICITY 
# -DUSE_PERLIO -D__STDC__=1 -DUSE_SFIO -DI_SFIO -I\sfio97\include

.IMPORT .IGNORE : PROCESSOR_ARCHITECTURE

PROCESSOR_ARCHITECTURE *= x86

.IF "$(USE_THREADS)" == "define"
ARCHNAME	= MSWin32-$(PROCESSOR_ARCHITECTURE)-thread
.ELSE
ARCHNAME	= MSWin32-$(PROCESSOR_ARCHITECTURE)
.ENDIF

ARCHDIR		= ..\lib\$(ARCHNAME)
COREDIR		= ..\lib\CORE
AUTODIR		= ..\lib\auto

#
# Programs to compile, build .lib files and link
#

.USESHELL :

.IF "$(CCTYPE)" == "BORLAND"

CC		= bcc32
LINK32		= tlink32
LIB32		= tlib /P128
IMPLIB		= implib -c

#
# Options
#
RUNTIME		= -D_RTLDLL
INCLUDES	= -I.\include -I. -I.. -I$(CCINCDIR)
#PCHFLAGS	= -H -Hc -H=c:\temp\bcmoduls.pch 
DEFINES		= -DWIN32 $(BUILDOPT) $(CRYPT_FLAG)
LOCDEFS		= -DPERLDLL -DPERL_CORE
SUBSYS		= console
CXX_FLAG	= -P

LIBC		= cw32mti.lib
LIBFILES	= $(CRYPT_LIB) import32.lib $(LIBC) odbc32.lib odbccp32.lib

.IF  "$(CFG)" == "Debug"
OPTIMIZE	= -v $(RUNTIME) -DDEBUGGING
LINK_DBG	= -v
.ELSE
OPTIMIZE	= -O2 $(RUNTIME)
LINK_DBG	= 
.ENDIF

CFLAGS		= -w -d -tWM -tWD $(INCLUDES) $(DEFINES) $(LOCDEFS) \
		$(PCHFLAGS) $(OPTIMIZE)
LINK_FLAGS	= $(LINK_DBG) -L$(CCLIBDIR)
OBJOUT_FLAG	= -o
EXEOUT_FLAG	= -e
LIBOUT_FLAG	= 

.ELIF "$(CCTYPE)" == "GCC"

CC		= gcc -pipe
LINK32		= gcc -pipe
LIB32		= ar rc
IMPLIB		= dlltool

o = .o

#
# Options
#
RUNTIME		=
INCLUDES	= -I.\include -I. -I..
DEFINES		= -DWIN32 $(BUILDOPT) $(CRYPT_FLAG)
LOCDEFS		= -DPERLDLL -DPERL_CORE
SUBSYS		= console
CXX_FLAG	= -xc++

LIBC		= -lcrtdll
LIBFILES	= $(CRYPT_LIB) -ladvapi32 -luser32 -lnetapi32 -lwsock32 -lmingw32 \
		-lgcc -lmoldname $(LIBC) -lkernel32

.IF  "$(CFG)" == "Debug"
OPTIMIZE	= -g -O2 $(RUNTIME) -DDEBUGGING
LINK_DBG	= -g
.ELSE
OPTIMIZE	= -g -O2 $(RUNTIME)
LINK_DBG	= 
.ENDIF

CFLAGS		= $(INCLUDES) $(DEFINES) $(LOCDEFS) $(OPTIMIZE)
LINK_FLAGS	= $(LINK_DBG) -L$(CCLIBDIR)
OBJOUT_FLAG	= -o
EXEOUT_FLAG	= -o
LIBOUT_FLAG	= 

.ELSE

CC		= cl.exe
LINK32		= link.exe
LIB32		= $(LINK32) -lib

#
# Options
#

RUNTIME		= -MD
INCLUDES	= -I.\include -I. -I..
#PCHFLAGS	= -Fpc:\temp\vcmoduls.pch -YX 
DEFINES		= -DWIN32 -D_CONSOLE $(BUILDOPT) $(CRYPT_FLAG)
LOCDEFS		= -DPERLDLL -DPERL_CORE
SUBSYS		= console
CXX_FLAG	= -TP -GX

.IF "$(RUNTIME)" == "-MD"
LIBC		= msvcrt.lib
.ELSE
LIBC		= libcmt.lib
.ENDIF

.IF  "$(CFG)" == "Debug"
.IF "$(CCTYPE)" == "MSVC20"
OPTIMIZE	= -Od $(RUNTIME) -Z7 -D_DEBUG -DDEBUGGING
.ELSE
OPTIMIZE	= -Od $(RUNTIME)d -Zi -D_DEBUG -DDEBUGGING
.ENDIF
LINK_DBG	= -debug -pdb:none
.ELSE
.IF "$(CCTYPE)" == "MSVC20"
OPTIMIZE	= -Od $(RUNTIME) -DNDEBUG
.ELSE
OPTIMIZE	= -Od $(RUNTIME) -DNDEBUG
.ENDIF
LINK_DBG	= -release
.ENDIF

# we don't add LIBC here, the compiler does it based on -MD/-MT
LIBFILES	= $(CRYPT_LIB) oldnames.lib kernel32.lib user32.lib gdi32.lib \
		winspool.lib comdlg32.lib advapi32.lib shell32.lib ole32.lib \
		oleaut32.lib netapi32.lib uuid.lib wsock32.lib mpr.lib winmm.lib \
		version.lib odbc32.lib odbccp32.lib

CFLAGS		= -nologo -Gf -W3 $(INCLUDES) $(DEFINES) $(LOCDEFS) \
		$(PCHFLAGS) $(OPTIMIZE)
LINK_FLAGS	= -nologo $(LINK_DBG) -machine:$(PROCESSOR_ARCHITECTURE)
OBJOUT_FLAG	= -Fo
EXEOUT_FLAG	= -Fe
LIBOUT_FLAG	= /out:

.ENDIF

.IF "$(OBJECT)" != ""
OPTIMIZE	+= $(CXX_FLAG)
.ENDIF

CFLAGS_O	= $(CFLAGS) $(OBJECT)

#################### do not edit below this line #######################
############# NO USER-SERVICEABLE PARTS BEYOND THIS POINT ##############

o *= .obj

LKPRE		= INPUT (
LKPOST		= )

#
# Rules
# 

.SUFFIXES : .c $(o) .dll .lib .exe .a

.c$(o):
	$(CC) -c $(null,$(<:d) $(NULL) -I$(<:d)) $(CFLAGS_O) $(OBJOUT_FLAG)$@ $<

.y.c:
	$(NOOP)

$(o).dll:
.IF "$(CCTYPE)" == "BORLAND"
	$(LINK32) -Tpd -ap $(LINK_FLAGS) c0d32$(o) $<,$@,,$(LIBFILES),$(*B).def
	$(IMPLIB) $(*B).lib $@
.ELIF "$(CCTYPE)" == "GCC"
	$(LINK32) -o $@ $(LINK_FLAGS) $< $(LIBFILES)
	$(IMPLIB) -def $(*B).def $(*B).lib $@
.ELSE
	$(LINK32) -dll -subsystem:windows -implib:$(*B).lib -def:$(*B).def \
	    -out:$@ $(LINK_FLAGS) $(LIBFILES) $< $(LIBPERL)  
.ENDIF

#
INST_BIN	= $(INST_TOP)$(INST_VER)\bin\$(ARCHNAME)
INST_SCRIPT	= $(INST_TOP)$(INST_VER)\bin
INST_LIB	= $(INST_TOP)$(INST_VER)\lib
INST_POD	= $(INST_LIB)\pod
INST_HTML	= $(INST_POD)\html
LIBDIR		= ..\lib
EXTDIR		= ..\ext
PODDIR		= ..\pod
EXTUTILSDIR	= $(LIBDIR)\extutils

#
# various targets
.IF "$(OBJECT)" == "-DPERL_OBJECT"
PERLIMPLIB	= ..\perlcore.lib
PERLDLL		= ..\perlcore.dll
CAPILIB		= $(COREDIR)\PerlCAPI.lib
.ELSE
PERLIMPLIB	= ..\perl.lib
PERLDLL		= ..\perl.dll
CAPILIB		=
.ENDIF

MINIPERL	= ..\miniperl.exe
MINIDIR		= .\mini
PERLEXE		= ..\perl.exe
GLOBEXE		= ..\perlglob.exe
CONFIGPM	= ..\lib\Config.pm
MINIMOD		= ..\lib\ExtUtils\Miniperl.pm
X2P		= ..\x2p\a2p.exe

PL2BAT		= bin\pl2bat.pl
GLOBBAT		= bin\perlglob.bat

.IF "$(CCTYPE)" == "BORLAND"

CFGSH_TMPL	= config.bc
CFGH_TMPL	= config_H.bc

.ELIF "$(CCTYPE)" == "GCC"

CFGSH_TMPL	= config.gc
CFGH_TMPL	= config_H.gc

.ELSE

CFGSH_TMPL	= config.vc
CFGH_TMPL	= config_H.vc
PERL95EXE	= ..\perl95.exe

.ENDIF

XCOPY		= xcopy /f /r /i /d
RCOPY		= xcopy /f /r /i /e /d
NOOP		= @echo

#
# filenames given to xsubpp must have forward slashes (since it puts
# full pathnames in #line strings)
XSUBPP		= ..\$(MINIPERL) -I..\..\lib ..\$(EXTUTILSDIR)\xsubpp \
		-C++ -prototypes

CORE_SRC	=		\
		..\av.c		\
		..\byterun.c	\
		..\deb.c	\
		..\doio.c	\
		..\doop.c	\
		..\dump.c	\
		..\globals.c	\
		..\gv.c		\
		..\hv.c		\
		..\mg.c		\
		..\op.c		\
		..\perl.c	\
		..\perly.c	\
		..\pp.c		\
		..\pp_ctl.c	\
		..\pp_hot.c	\
		..\pp_sys.c	\
		..\regcomp.c	\
		..\regexec.c	\
		..\run.c	\
		..\scope.c	\
		..\sv.c		\
		..\taint.c	\
		..\toke.c	\
		..\universal.c	\
		..\util.c

.IF "$(CRYPT_SRC)" != ""
CORE_SRC	+= ..\$(CRYPT_SRC)
.ENDIF

.IF "$(PERL_MALLOC)" == "define"
CORE_SRC	+= ..\malloc.c
.ENDIF

.IF "$(OBJECT)" == ""
CORE_SRC	+= ..\perlio.c
.ENDIF

WIN32_SRC	=		\
		.\win32.c	\
		.\win32sck.c

.IF "$(USE_THREADS)" == "define"
WIN32_SRC	+= .\win32thread.c 
.ENDIF

PERL95_SRC	=		\
		perl95.c	\
		win32mt.c	\
		win32sckmt.c

.IF "$(CRYPT_SRC)" != ""
PERL95_SRC	+= ..\$(CRYPT_SRC)
.ENDIF

DLL_SRC		= $(DYNALOADER).c


.IF "$(OBJECT)" == ""
DLL_SRC		+= perllib.c
.ENDIF

X2P_SRC		=		\
		..\x2p\a2p.c	\
		..\x2p\hash.c	\
		..\x2p\str.c	\
		..\x2p\util.c	\
		..\x2p\walk.c

CORE_H		=		\
		..\av.h		\
		..\byterun.h	\
		..\bytecode.h	\
		..\cop.h	\
		..\cv.h		\
		..\dosish.h	\
		..\embed.h	\
		..\form.h	\
		..\gv.h		\
		..\handy.h	\
		..\hv.h		\
		..\mg.h		\
		..\nostdio.h	\
		..\op.h		\
		..\opcode.h	\
		..\perl.h	\
		..\perlio.h	\
		..\perlsdio.h	\
		..\perlsfio.h	\
		..\perly.h	\
		..\pp.h		\
		..\proto.h	\
		..\regexp.h	\
		..\scope.h	\
		..\sv.h		\
		..\thread.h	\
		..\unixish.h	\
		..\util.h	\
		..\XSUB.h	\
		.\config.h	\
		..\EXTERN.h	\
		..\perlvars.h	\
		..\intrpvar.h	\
		..\thrdvar.h	\
		.\include\dirent.h	\
		.\include\netdb.h	\
		.\include\sys\socket.h	\
		.\win32.h

CORE_OBJ	= $(CORE_SRC:db:+$(o))
WIN32_OBJ	= $(WIN32_SRC:db:+$(o))
MINICORE_OBJ	= $(MINIDIR)\{$(CORE_OBJ:f) miniperlmain$(o)}
MINIWIN32_OBJ	= $(MINIDIR)\{$(WIN32_OBJ:f)}
MINI_OBJ	= $(MINICORE_OBJ) $(MINIWIN32_OBJ)
PERL95_OBJ	= $(PERL95_SRC:db:+$(o))
DLL_OBJ		= $(DLL_SRC:db:+$(o))
X2P_OBJ		= $(X2P_SRC:db:+$(o))

.IF "$(OBJECT)" != ""
MINICORE_OBJ	+= $(MINIDIR)\perlio$(o)
.ENDIF

PERLDLL_OBJ	= $(CORE_OBJ)
PERLEXE_OBJ	= perlmain$(o)

.IF "$(OBJECT)" == ""
PERLDLL_OBJ	+= $(WIN32_OBJ) $(DLL_OBJ)
.ELSE
PERLEXE_OBJ	+= $(WIN32_OBJ) $(DLL_OBJ)
PERL95_OBJ	+= DynaLoadmt$(o)
.ENDIF

DYNAMIC_EXT	= Socket IO Fcntl Opcode SDBM_File POSIX attrs Thread B
STATIC_EXT	= DynaLoader

DYNALOADER	= $(EXTDIR)\DynaLoader\DynaLoader
SOCKET		= $(EXTDIR)\Socket\Socket
FCNTL		= $(EXTDIR)\Fcntl\Fcntl
OPCODE		= $(EXTDIR)\Opcode\Opcode
SDBM_FILE	= $(EXTDIR)\SDBM_File\SDBM_File
IO		= $(EXTDIR)\IO\IO
POSIX		= $(EXTDIR)\POSIX\POSIX
ATTRS		= $(EXTDIR)\attrs\attrs
THREAD		= $(EXTDIR)\Thread\Thread
B		= $(EXTDIR)\B\B

SOCKET_DLL	= $(AUTODIR)\Socket\Socket.dll
FCNTL_DLL	= $(AUTODIR)\Fcntl\Fcntl.dll
OPCODE_DLL	= $(AUTODIR)\Opcode\Opcode.dll
SDBM_FILE_DLL	= $(AUTODIR)\SDBM_File\SDBM_File.dll
IO_DLL		= $(AUTODIR)\IO\IO.dll
POSIX_DLL	= $(AUTODIR)\POSIX\POSIX.dll
ATTRS_DLL	= $(AUTODIR)\attrs\attrs.dll
THREAD_DLL	= $(AUTODIR)\Thread\Thread.dll
B_DLL		= $(AUTODIR)\B\B.dll

EXTENSION_C	=		\
		$(SOCKET).c	\
		$(FCNTL).c	\
		$(OPCODE).c	\
		$(SDBM_FILE).c	\
		$(IO).c		\
		$(POSIX).c	\
		$(ATTRS).c	\
		$(THREAD).c	\
		$(B).c

EXTENSION_DLL	=		\
		$(SOCKET_DLL)	\
		$(FCNTL_DLL)	\
		$(OPCODE_DLL)	\
		$(SDBM_FILE_DLL)\
		$(IO_DLL)	\
		$(POSIX_DLL)	\
		$(ATTRS_DLL)	\
		$(B_DLL)

.IF "$(OBJECT)" == ""
EXTENSION_DLL	+=		\
		$(THREAD_DLL)
.ENDIF

POD2HTML	= $(PODDIR)\pod2html
POD2MAN		= $(PODDIR)\pod2man
POD2LATEX	= $(PODDIR)\pod2latex
POD2TEXT	= $(PODDIR)\pod2text

CFG_VARS	=					\
		"INST_DRV=$(INST_DRV)"			\
		"INST_TOP=$(INST_TOP)"			\
		"INST_VER=$(INST_VER)"			\
		"archname=$(ARCHNAME)"			\
		"cc=$(CC)"				\
		"ccflags=$(OPTIMIZE) $(DEFINES) $(OBJECT)"	\
		"cf_email=$(EMAIL)"			\
		"d_crypt=$(D_CRYPT)"			\
		"d_mymalloc=$(PERL_MALLOC)"		\
		"libs=$(LIBFILES:f)"			\
		"incpath=$(CCINCDIR)"			\
		"libperl=$(PERLIMPLIB)"			\
		"libpth=$(strip $(CCLIBDIR) $(LIBFILES:d))" \
		"libc=$(LIBC)"				\
		"make=dmake"				\
		"static_ext=$(STATIC_EXT)"		\
		"dynamic_ext=$(DYNAMIC_EXT)"		\
		"usethreads=$(USE_THREADS)"		\
		"LINK_FLAGS=$(LINK_FLAGS)"		\
		"optimize=$(OPTIMIZE)"

#
# Top targets
#

all : $(GLOBEXE) $(MINIMOD) $(CONFIGPM) $(PERLEXE) $(PERL95EXE) $(CAPILIB) $(X2P) \
	$(EXTENSION_DLL)

$(DYNALOADER)$(o) : $(DYNALOADER).c $(CORE_H) $(EXTDIR)\DynaLoader\dlutils.c

#------------------------------------------------------------

$(GLOBEXE) : perlglob$(o)
.IF "$(CCTYPE)" == "BORLAND"
	$(CC) -c -w -v -tWM -I$(CCINCDIR) perlglob.c
	$(LINK32) -Tpe -ap $(LINK_FLAGS) c0x32$(o) perlglob$(o) \
	    $(CCLIBDIR)\32BIT\wildargs$(o),$@,,import32.lib cw32mt.lib,
.ELIF "$(CCTYPE)" == "GCC"
	$(LINK32) $(LINK_FLAGS) -o $@ perlglob$(o) $(LIBFILES)
.ELSE
	$(LINK32) $(LINK_FLAGS) $(LIBFILES) -out:$@ -subsystem:$(SUBSYS) \
	    perlglob$(o) setargv$(o) 
.ENDIF

perlglob$(o)  : perlglob.c

config.w32 : $(CFGSH_TMPL)
	copy $(CFGSH_TMPL) config.w32

.\config.h : $(CFGH_TMPL)
	-del /f config.h
	copy $(CFGH_TMPL) config.h

..\config.sh : config.w32 $(MINIPERL) config_sh.PL
	$(MINIPERL) -I..\lib config_sh.PL $(CFG_VARS) config.w32 > ..\config.sh

# this target is for when changes to the main config.sh happen
# edit config.{b,v,g}c and make this target once for each supported
# compiler (e.g. `dmake CCTYPE=BORLAND regen_config_h`)
regen_config_h:
	perl config_sh.PL $(CFG_VARS) $(CFGSH_TMPL) > ..\config.sh
	-cd .. && del /f perl.exe
	cd .. && perl configpm
	-del /f $(CFGH_TMPL)
	-mkdir ..\lib\CORE
	-perl -I..\lib config_h.PL "INST_VER=$(INST_VER)"
	rename config.h $(CFGH_TMPL)

$(CONFIGPM) : $(MINIPERL) ..\config.sh config_h.PL ..\minimod.pl
	cd .. && miniperl configpm
	if exist lib\* $(RCOPY) lib\*.* ..\lib\$(NULL)
	$(XCOPY) ..\*.h $(COREDIR)\*.*
	$(XCOPY) *.h $(COREDIR)\*.*
	$(RCOPY) include $(COREDIR)\*.*
	$(MINIPERL) -I..\lib config_h.PL "INST_VER=$(INST_VER)" \
	    || $(MAKE) $(MAKEMACROS) $(CONFIGPM)

$(MINIPERL) : $(MINIDIR) $(MINI_OBJ)
.IF "$(CCTYPE)" == "BORLAND"
	$(LINK32) -Tpe -ap $(LINK_FLAGS) \
	    @$(mktmp c0x32$(o) $(MINI_OBJ:s,\,\\),$(@:s,\,\\),,$(LIBFILES),)
.ELIF "$(CCTYPE)" == "GCC"
	$(LINK32) -v -o $@ $(LINK_FLAGS) \
	    $(mktmp $(LKPRE) $(MINI_OBJ:s,\,\\) $(LIBFILES) $(LKPOST))
.ELSE
	$(LINK32) -subsystem:console -out:$@ \
	    @$(mktmp $(LINK_FLAGS) $(LIBFILES) $(MINI_OBJ:s,\,\\))
.ENDIF

$(MINIDIR) :
	if not exist "$(MINIDIR)" mkdir "$(MINIDIR)"

$(MINICORE_OBJ) : $(CORE_H)
	$(CC) -c $(CFLAGS) $(OBJOUT_FLAG)$@ ..\$(*B).c

$(MINIWIN32_OBJ) : $(CORE_H)
	$(CC) -c $(CFLAGS) $(OBJOUT_FLAG)$@ $(*B).c

$(WIN32_OBJ)	: $(CORE_H)
$(CORE_OBJ)	: $(CORE_H)
$(MINI_OBJ)	: $(CORE_H)
$(DLL_OBJ)	: $(CORE_H)
$(PERL95_OBJ)	: $(CORE_H)
$(X2P_OBJ)	: $(CORE_H)

perldll.def : $(MINIPERL) $(CONFIGPM) ..\global.sym makedef.pl
	$(MINIPERL) -w makedef.pl $(OPTIMIZE) $(DEFINES) $(OBJECT) \
	    CCTYPE=$(CCTYPE) > perldll.def

$(PERLDLL): perldll.def $(PERLDLL_OBJ)
.IF "$(CCTYPE)" == "BORLAND"
	$(LINK32) -Tpd -ap $(LINK_FLAGS) \
	    @$(mktmp c0d32$(o) $(PERLDLL_OBJ:s,\,\\)\n \
		$@,\n \
		$(LIBFILES)\n \
		perldll.def\n)
	$(IMPLIB) $*.lib $@
.ELIF "$(CCTYPE)" == "GCC"
	$(LINK32) -mdll -o $@ -Wl,--base-file -Wl,perl.base $(LINK_FLAGS) \
	    $(mktmp $(LKPRE) $(PERLDLL_OBJ:s,\,\\) $(LIBFILES) $(LKPOST))
	dlltool --output-lib $(PERLIMPLIB) \
                --dllname perl.dll \
                --def perldll.def \
                --base-file perl.base \
                --output-exp perl.exp
	$(LINK32) -mdll -o $@ $(LINK_FLAGS) \
	    $(mktmp $(LKPRE) $(PERLDLL_OBJ:s,\,\\) $(LIBFILES) \
		perl.exp $(LKPOST))
.ELSE
	$(LINK32) -dll -def:perldll.def -out:$@ \
	    @$(mktmp $(LINK_FLAGS) $(LIBFILES) $(PERLDLL_OBJ:s,\,\\))
.ENDIF
	$(XCOPY) $(PERLIMPLIB) $(COREDIR)

perl.def  : $(MINIPERL) makeperldef.pl
	$(MINIPERL) -I..\lib makeperldef.pl $(NULL) > perl.def

$(MINIMOD) : $(MINIPERL) ..\minimod.pl
	cd .. && miniperl minimod.pl > lib\ExtUtils\Miniperl.pm

..\x2p\a2p$(o) : ..\x2p\a2p.c
	$(CC) -I..\x2p $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\a2p.c

..\x2p\hash$(o) : ..\x2p\hash.c
	$(CC) -I..\x2p  $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\hash.c

..\x2p\str$(o) : ..\x2p\str.c
	$(CC) -I..\x2p  $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\str.c

..\x2p\util$(o) : ..\x2p\util.c
	$(CC) -I..\x2p  $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\util.c

..\x2p\walk$(o) : ..\x2p\walk.c
	$(CC) -I..\x2p  $(CFLAGS) $(OBJOUT_FLAG)$@ -c ..\x2p\walk.c

$(X2P) : $(MINIPERL) $(X2P_OBJ)
	$(MINIPERL) ..\x2p\find2perl.PL
	$(MINIPERL) ..\x2p\s2p.PL
.IF "$(CCTYPE)" == "BORLAND"
	$(LINK32) -Tpe -ap $(LINK_FLAGS) \
	    @$(mktmp c0x32$(o) $(X2P_OBJ:s,\,\\),$(@:s,\,\\),,$(LIBFILES),)
.ELIF "$(CCTYPE)" == "GCC"
	$(LINK32) -v -o $@ $(LINK_FLAGS) \
	    $(mktmp $(LKPRE) $(X2P_OBJ:s,\,\\) $(LIBFILES) $(LKPOST))
.ELSE
	$(LINK32) -subsystem:console -out:$@ \
	    @$(mktmp $(LINK_FLAGS) $(LIBFILES) $(X2P_OBJ:s,\,\\))
.ENDIF

perlmain.c : runperl.c 
	copy runperl.c perlmain.c

perlmain$(o) : perlmain.c
	$(CC) $(CFLAGS_O) -UPERLDLL $(OBJOUT_FLAG)$@ -c perlmain.c

$(PERLEXE): $(PERLDLL) $(CONFIGPM) $(PERLEXE_OBJ)
.IF "$(CCTYPE)" == "BORLAND"
	$(LINK32) -Tpe -ap $(LINK_FLAGS) \
	    @$(mktmp c0x32$(o) $(PERLEXE_OBJ:s,\,\\)\n \
	    $(@:s,\,\\),\n \
	    $(PERLIMPLIB) $(LIBFILES)\n)
.ELIF "$(CCTYPE)" == "GCC"
	$(LINK32) -o $@ $(LINK_FLAGS)  \
	    $(PERLEXE_OBJ) $(PERLIMPLIB) $(LIBFILES)
.ELSE
	$(LINK32) -subsystem:console -out:$@ $(LINK_FLAGS) $(LIBFILES) \
	    $(PERLEXE_OBJ) $(PERLIMPLIB) 
.ENDIF
	copy splittree.pl .. 
	$(MINIPERL) -I..\lib ..\splittree.pl "../LIB" $(AUTODIR)

.IF "$(CCTYPE)" != "BORLAND"
.IF "$(CCTYPE)" != "GCC"

perl95.c : runperl.c 
	copy runperl.c perl95.c

perl95$(o) : perl95.c
	$(CC) $(CFLAGS_O) -MT -UPERLDLL -DWIN95FIX -c perl95.c

win32sckmt$(o) : win32sck.c
	$(CC) $(CFLAGS_O) -MT -UPERLDLL -DWIN95FIX -c \
	    $(OBJOUT_FLAG)win32sckmt$(o) win32sck.c

win32mt$(o) : win32.c
	$(CC) $(CFLAGS_O) -MT -UPERLDLL -DWIN95FIX -c \
	    $(OBJOUT_FLAG)win32mt$(o) win32.c

DynaLoadmt$(o) : $(DYNALOADER).c
	$(CC) $(CFLAGS_O) -MT -UPERLDLL -DWIN95FIX -c \
	    $(OBJOUT_FLAG)DynaLoadmt$(o) $(DYNALOADER).c

$(PERL95EXE): $(PERLDLL) $(CONFIGPM) $(PERL95_OBJ)
	$(LINK32) -subsystem:console -nodefaultlib -out:$@ $(LINK_FLAGS) \
	    $(LIBFILES) $(PERL95_OBJ) $(PERLIMPLIB) libcmt.lib

.ENDIF
.ENDIF

$(DYNALOADER).c: $(MINIPERL) $(EXTDIR)\DynaLoader\dl_win32.xs $(CONFIGPM)
	if not exist $(AUTODIR) mkdir $(AUTODIR)
	cd $(EXTDIR)\$(*B) && ..\$(MINIPERL) -I..\..\lib $(*B).pm.PL
	$(XCOPY) $(EXTDIR)\$(*B)\$(*B).pm $(LIBDIR)\$(NULL)
	cd $(EXTDIR)\$(*B) && $(XSUBPP) dl_win32.xs > $(*B).c
	$(XCOPY) $(EXTDIR)\$(*B)\dlutils.c .

.IF "$(OBJECT)" == "-DPERL_OBJECT"

PerlCAPI.cpp : $(MINIPERL)
	$(MINIPERL) GenCAPI.pl $(COREDIR)

PerlCAPI$(o) : PerlCAPI.cpp
.IF "$(CCTYPE)" == "BORLAND"
	$(CC) $(CFLAGS_O) -c $(OBJOUT_FLAG)PerlCAPI$(o) PerlCAPI.cpp
.ELIF "$(CCTYPE)" == "GCC"
	$(CC) $(CFLAGS_O) -c $(OBJOUT_FLAG)PerlCAPI$(o) PerlCAPI.cpp
.ELSE
	$(CC) $(CFLAGS_O) -MT -UPERLDLL -DWIN95FIX -c \
	    $(OBJOUT_FLAG)PerlCAPI$(o) PerlCAPI.cpp
.ENDIF

$(CAPILIB) : PerlCAPI.cpp PerlCAPI$(o)
.IF "$(CCTYPE)" == "BORLAND"
	$(LIB32) $(LIBOUT_FLAG)$(CAPILIB) +PerlCAPI$(o)
.ELSE
	$(LIB32) $(LIBOUT_FLAG)$(CAPILIB) PerlCAPI$(o)
.ENDIF

.ENDIF

$(EXTDIR)\DynaLoader\dl_win32.xs: dl_win32.xs
	copy dl_win32.xs $(EXTDIR)\DynaLoader\dl_win32.xs

$(B_DLL): $(PERLEXE) $(B).xs
	cd $(EXTDIR)\$(*B) && \
	..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl
	cd $(EXTDIR)\$(*B) && $(MAKE)

$(THREAD_DLL): $(PERLEXE) $(THREAD).xs
	cd $(EXTDIR)\$(*B) && \
	..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl
	cd $(EXTDIR)\$(*B) && $(MAKE)

$(ATTRS_DLL): $(PERLEXE) $(ATTRS).xs
	cd $(EXTDIR)\$(*B) && \
	..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl
	cd $(EXTDIR)\$(*B) && $(MAKE)

$(POSIX_DLL): $(PERLEXE) $(POSIX).xs
	cd $(EXTDIR)\$(*B) && \
	..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl
	cd $(EXTDIR)\$(*B) && $(MAKE)

$(IO_DLL): $(PERLEXE) $(IO).xs
	cd $(EXTDIR)\$(*B) && \
	..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl
	cd $(EXTDIR)\$(*B) && $(MAKE)

$(SDBM_FILE_DLL) : $(PERLEXE) $(SDBM_FILE).xs
	cd $(EXTDIR)\$(*B) && \
	..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl
	cd $(EXTDIR)\$(*B) && $(MAKE)

$(FCNTL_DLL): $(PERLEXE) $(FCNTL).xs
	cd $(EXTDIR)\$(*B) && \
	..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl
	cd $(EXTDIR)\$(*B) && $(MAKE)

$(OPCODE_DLL): $(PERLEXE) $(OPCODE).xs
	cd $(EXTDIR)\$(*B) && \
	..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl
	cd $(EXTDIR)\$(*B) && $(MAKE)

$(SOCKET_DLL): $(PERLEXE) $(SOCKET).xs
	cd $(EXTDIR)\$(*B) && \
	..\..\miniperl -I..\..\lib Makefile.PL INSTALLDIRS=perl
	cd $(EXTDIR)\$(*B) && $(MAKE)

doc: $(PERLEXE)
	cd ..\pod && $(MAKE) -f ..\win32\pod.mak checkpods \
		pod2html pod2latex pod2man pod2text
	cd ..\pod && $(XCOPY) *.bat ..\win32\bin\*.*
	copy ..\README.win32 ..\pod\perlwin32.pod
	$(PERLEXE) -I..\lib ..\installhtml --podroot=.. --htmldir=./html \
	    --podpath=pod:lib:ext:utils --htmlroot="file://$(INST_HTML:s,:,|,)"\
	    --libpod=perlfunc:perlguts:perlvar:perlrun:perlop --recurse

utils: $(PERLEXE)
	cd ..\utils && $(MAKE) PERL=$(MINIPERL)
	cd ..\utils && $(PERLEXE) ..\win32\$(PL2BAT) h2ph splain perlbug \
		pl2pm c2ph h2xs perldoc pstruct
	$(XCOPY) ..\utils\*.bat bin\*.*
	$(PERLEXE) -I..\lib $(PL2BAT) bin\network.pl bin\www.pl bin\runperl.pl \
			bin\pl2bat.pl bin\perlglob.pl

distclean: clean
	-del /f $(MINIPERL) $(PERLEXE) $(PERL95EXE) $(PERLDLL) $(GLOBEXE) \
		$(PERLIMPLIB) ..\miniperl.lib $(MINIMOD)
	-del /f *.def *.map
	-del /f $(EXTENSION_DLL)
	-del /f $(EXTENSION_C) $(DYNALOADER).c
	-del /f $(EXTDIR)\DynaLoader\dl_win32.xs
	-del /f $(LIBDIR)\.exists $(LIBDIR)\attrs.pm $(LIBDIR)\DynaLoader.pm
	-del /f $(LIBDIR)\Fcntl.pm $(LIBDIR)\IO.pm $(LIBDIR)\Opcode.pm
	-del /f $(LIBDIR)\ops.pm $(LIBDIR)\Safe.pm $(LIBDIR)\Thread.pm
	-del /f $(LIBDIR)\SDBM_File.pm $(LIBDIR)\Socket.pm $(LIBDIR)\POSIX.pm
	-del /f $(LIBDIR)\B.pm $(LIBDIR)\O.pm
	-rmdir /s /q $(LIBDIR)\IO || rmdir /s $(LIBDIR)\IO
	-rmdir /s /q $(LIBDIR)\Thread || rmdir /s $(LIBDIR)\Thread
	-rmdir /s /q $(LIBDIR)\B || rmdir /s $(LIBDIR)\B
	-del /f $(PODDIR)\*.html
	-del /f $(PODDIR)\*.bat
	-cd ..\utils && del /f h2ph splain perlbug pl2pm c2ph h2xs perldoc pstruct *.bat
	-cd ..\x2p && del /f find2perl s2p *.bat
	-del /f ..\config.sh ..\splittree.pl perlmain.c dlutils.c config.h.new
	-del /f $(CONFIGPM)
.IF "$(PERL95EXE)" != ""
	-del /f perl95.c
.ENDIF
	-del /f bin\*.bat
	-cd $(EXTDIR) && del /s *.lib *.def *.map *.bs Makefile *$(o) pm_to_blib
	-rmdir /s /q $(AUTODIR) || rmdir /s $(AUTODIR)
	-rmdir /s /q $(COREDIR) || rmdir /s $(COREDIR)

install : all installbare installutils installhtml

installbare :
	$(PERLEXE) ..\installperl
.IF "$(PERL95EXE)" != ""
	$(XCOPY) $(PERL95EXE) $(INST_BIN)\*.*
.ENDIF

installutils : utils
	$(XCOPY) $(GLOBEXE) $(INST_BIN)\*.*
	$(XCOPY) bin\*.bat $(INST_SCRIPT)\*.*
	$(XCOPY) ..\pod\*.bat $(INST_SCRIPT)\*.*

installhtml : doc
	$(RCOPY) html\*.* $(INST_HTML)\*.*

inst_lib : $(CONFIGPM)
	copy splittree.pl .. 
	$(MINIPERL) -I..\lib ..\splittree.pl "../LIB" $(AUTODIR)
	$(RCOPY) ..\lib $(INST_LIB)\*.*

minitest : $(MINIPERL) $(GLOBEXE) $(CONFIGPM) utils
	$(XCOPY) $(MINIPERL) ..\t\perl.exe
.IF "$(CCTYPE)" == "BORLAND"
	$(XCOPY) $(GLOBBAT) ..\t\$(NULL)
.ELSE
	$(XCOPY) $(GLOBEXE) ..\t\$(NULL)
.ENDIF
	attrib -r ..\t\*.*
	copy test ..\t
	cd ..\t && \
	$(MINIPERL) -I..\lib test base/*.t comp/*.t cmd/*.t io/*.t op/*.t pragma/*.t

test-prep : all utils
	$(XCOPY) $(PERLEXE) ..\t\$(NULL)
	$(XCOPY) $(PERLDLL) ..\t\$(NULL)
.IF "$(CCTYPE)" == "BORLAND"
	$(XCOPY) $(GLOBBAT) ..\t\$(NULL)
.ELSE
	$(XCOPY) $(GLOBEXE) ..\t\$(NULL)
.ENDIF

test : test-prep
	cd ..\t && $(PERLEXE) -I..\lib harness

test-notty : test-prep
	set PERL_SKIP_TTY_TEST=1 && \
	cd ..\t && $(PERLEXE) -I.\lib harness

clean : 
	-@erase miniperlmain$(o)
	-@erase $(MINIPERL)
	-@erase perlglob$(o)
	-@erase perlmain$(o)
	-@erase PerlCAPI.cpp
	-@erase config.w32
	-@erase /f config.h
	-@erase $(GLOBEXE)
	-@erase $(PERLEXE)
	-@erase $(PERLDLL)
	-@erase $(CORE_OBJ)
	-rmdir /s /q $(MINIDIR) || rmdir /s $(MINIDIR)
	-@erase $(WIN32_OBJ)
	-@erase $(DLL_OBJ)
	-@erase $(X2P_OBJ)
	-@erase ..\*$(o) ..\*.lib ..\*.exp *$(o) *.lib *.exp
	-@erase ..\t\*.exe ..\t\*.dll ..\t\*.bat
	-@erase ..\x2p\*.exe ..\x2p\*.bat
	-@erase *.ilk
	-@erase *.pdb
