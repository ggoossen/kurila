/* WIN32.H
 *
 * (c) 1995 Microsoft Corporation. All rights reserved. 
 * 		Developed by hip communications inc., http://info.hip.com/info/
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 */
#ifndef  _INC_WIN32_PERL5
#define  _INC_WIN32_PERL5

#ifdef __GNUC__
typedef long long __int64;
#define Win32_Winsock
/* GCC does not do __declspec() - render it a nop 
 * and turn on options to avoid importing data 
 */
#define __declspec(x)
#define PERL_GLOBAL_STRUCT
#define MULTIPLICITY
#ifndef TLS_OUT_OF_INDEXES
#define TLS_OUT_OF_INDEXES (DWORD)0xFFFFFFFF
#endif
#endif

/* Define DllExport akin to perl's EXT, 
 * If we are in the DLL or mimicing the DLL for Win95 work round
 * then Export the symbol, 
 * otherwise import it.
 */

#if defined(PERLDLL) || defined(WIN95FIX)
#define DllExport __declspec(dllexport)
#else 
#define DllExport __declspec(dllimport)
#endif

#define  WIN32_LEAN_AND_MEAN
#include <windows.h>

#ifdef   WIN32_LEAN_AND_MEAN		/* C file is NOT a Perl5 original. */
#define  CONTEXT	PERL_CONTEXT	/* Avoid conflict of CONTEXT defs. */
#define  index		strchr		/* Why 'index'? */
#endif /*WIN32_LEAN_AND_MEAN */

#include <dirent.h>
#include <io.h>
#include <process.h>
#include <stdio.h>
#include <direct.h>
#include <stdlib.h>
#ifndef EXT
#include "EXTERN.h"
#endif

struct tms {
	long	tms_utime;
	long	tms_stime;
	long	tms_cutime;
	long	tms_cstime;
};

#ifndef START_EXTERN_C
#ifdef __cplusplus
#  define START_EXTERN_C extern "C" {
#  define END_EXTERN_C }
#  define EXTERN_C extern "C"
#else
#  define START_EXTERN_C 
#  define END_EXTERN_C 
#  define EXTERN_C
#endif
#endif

#define  STANDARD_C	1
#define  DOSISH		1		/* no escaping our roots */
#define  OP_BINARY	O_BINARY	/* mistake in in pp_sys.c? */

/* Define USE_SOCKETS_AS_HANDLES to enable emulation of windows sockets as
 * real filehandles. XXX Should always be defined (the other version is untested) */
#define USE_SOCKETS_AS_HANDLES

/* if USE_WIN32_RTL_ENV is not defined, Perl uses direct Win32 calls
 * to read the environment, bypassing the runtime's (usually broken)
 * facilities for accessing the same.  See note in util.c/my_setenv(). */
/*#define USE_WIN32_RTL_ENV */

/* Define USE_FIXED_OSFHANDLE to fix VC's _open_osfhandle() on W95.
 * Can only enable it if not using the DLL CRT (it doesn't expose internals) */
#if defined(_MSC_VER) && !defined(_DLL) && defined(_M_IX86)
#define USE_FIXED_OSFHANDLE
#endif

#define ENV_IS_CASELESS

#ifndef VER_PLATFORM_WIN32_WINDOWS	/* VC-2.0 headers dont have this */
#define VER_PLATFORM_WIN32_WINDOWS	1
#endif

/* Compiler-specific stuff. */

#ifdef __BORLANDC__		/* Borland C++ */

#define _access access
#define _chdir chdir
#include <sys/types.h>

#ifndef DllMain
#define DllMain DllEntryPoint
#endif

#pragma warn -ccc	/* "condition is always true/false" */
#pragma warn -rch	/* "unreachable code" */
#pragma warn -sig	/* "conversion may lose significant digits" */
#pragma warn -pia	/* "possibly incorrect assignment" */
#pragma warn -par	/* "parameter 'foo' is never used" */
#pragma warn -aus	/* "'foo' is assigned a value that is never used" */
#pragma warn -use	/* "'foo' is declared but never used" */
#pragma warn -csu	/* "comparing signed and unsigned values" */
#pragma warn -pro	/* "call to function with no prototype" */

#endif

#ifdef _MSC_VER			/* Microsoft Visual C++ */

typedef long		uid_t;
typedef long		gid_t;
#pragma  warning(disable: 4018 4035 4101 4102 4244 4245 4761)

#endif /* _MSC_VER */

#ifdef __MINGW32__		/* Minimal Gnu-Win32 */

typedef long		uid_t;
typedef long		gid_t;

#endif /* __MINGW32__ */

/* compatibility stuff for other compilers goes here */


START_EXTERN_C

/* For UNIX compatibility. */

extern  uid_t	getuid(void);
extern  gid_t	getgid(void);
extern  uid_t	geteuid(void);
extern  gid_t	getegid(void);
extern  int	setuid(uid_t uid);
extern  int	setgid(gid_t gid);
extern  int	kill(int pid, int sig);
extern  void	*sbrk(int need);
extern	char *	getlogin(void);

#undef	 Stat
#define  Stat		win32_stat

#undef   init_os_extras
#define  init_os_extras Perl_init_os_extras

DllExport void		Perl_win32_init(int *argcp, char ***argvp);
DllExport void		Perl_init_os_extras(void);
DllExport void		win32_str_os_error(struct sv *s, DWORD err);

#ifndef USE_SOCKETS_AS_HANDLES
extern FILE *		my_fdopen(int, char *);
#endif
extern int		my_fclose(FILE *);
extern int		do_aspawn(void *really, void **mark, void **sp);
extern int		do_spawn(char *cmd);
extern int		do_spawn_nowait(char *cmd);
extern char		do_exec(char *cmd);
extern char *		win32_perllib_path(char *sfx,...);
extern int		IsWin95(void);
extern int		IsWinNT(void);

extern char *		staticlinkmodules[];

END_EXTERN_C

typedef  char *		caddr_t;	/* In malloc.c (core address). */

/*
 * handle socket stuff, assuming socket is always available
 */
#include <sys/socket.h>
#include <netdb.h>

#ifdef MYMALLOC
#define EMBEDMYMALLOC	/**/
/* #define USE_PERL_SBRK	/**/
/* #define PERL_SBRK_VIA_MALLOC	/**/
#endif

#if defined(PERLDLL) && !defined(PERL_CORE)
#define PERL_CORE
#endif

#ifdef USE_BINMODE_SCRIPTS
#define PERL_SCRIPT_MODE "rb"
EXT void win32_strip_return(struct sv *sv);
#else
#define PERL_SCRIPT_MODE "r"
#define win32_strip_return(sv) NOOP
#endif

/* 
 * Now Win32 specific per-thread data stuff 
 */

#ifdef USE_THREADS
#  ifndef USE_DECLSPEC_THREAD
#    define HAVE_THREAD_INTERN

struct thread_intern {
    /* XXX can probably use one buffer instead of several */
    char		Wstrerror_buffer[512];
    struct servent	Wservent;
    char		Wgetlogin_buffer[128];
#    ifdef HAVE_DES_FCRYPT
    char		Wcrypt_buffer[30];
#    endif
#    ifdef USE_RTL_THREAD_API
    void *		retv;	/* slot for thread return value */
#    endif
};
#  endif /* !USE_DECLSPEC_THREAD */
#endif /* USE_THREADS */

#endif /* _INC_WIN32_PERL5 */
