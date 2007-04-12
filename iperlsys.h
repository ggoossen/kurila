/*
 * iperlsys.h - Perl's interface to the system
 *
 * This file defines the system level functionality that perl needs.
 *
 * When using C, this definition is in the form of a set of macros
 * that can be #defined to the system-level function (or a wrapper
 * provided elsewhere).
 *
 * When using C++ with -DPERL_OBJECT, this definition is in the
 * form of a set of virtual base classes which must be subclassed to
 * provide a real implementation.  The Perl Object will use instances
 * of this implementation to use the system-level functionality.
 *
 * GSAR 21-JUN-98
 */

#ifndef __Inc__IPerl___
#define __Inc__IPerl___

/*
 *	PerlXXX_YYY explained - DickH and DougL @ ActiveState.com
 *
 * XXX := functional group
 * YYY := stdlib/OS function name
 *
 * Continuing with the theme of PerlIO, all OS functionality was
 * encapsulated into one of several interfaces.
 *
 * PerlIO - stdio
 * PerlLIO - low level I/O
 * PerlMem - malloc, realloc, free
 * PerlDir - directory related
 * PerlEnv - process environment handling
 * PerlProc - process control
 * PerlSock - socket functions
 *
 *
 * The features of this are:
 * 1. All OS dependant code is in the Perl Host and not the Perl Core.
 *    (At least this is the holy grail goal of this work)
 * 2. The Perl Host (see perl.h for description) can provide a new and
 *    improved interface to OS functionality if required.
 * 3. Developers can easily hook into the OS calls for instrumentation
 *    or diagnostic purposes.
 *
 * What was changed to do this:
 * 1. All calls to OS functions were replaced with PerlXXX_YYY
 *
 */


/*
    Interface for perl stdio functions
*/


/* Clean up (or at least document) the various possible #defines.
   This section attempts to match the 5.003_03 Configure variables
   onto the 5.003_02 header file values.
   I can't figure out where USE_STDIO was supposed to be set.
   --AD
*/
#ifndef USE_PERLIO
# define PERLIO_IS_STDIO
#endif

/* Below is the 5.003_02 stuff. */
#ifdef USE_STDIO
#  ifndef PERLIO_IS_STDIO
#      define PERLIO_IS_STDIO
#  endif
#else
extern void PerlIO_init (void);
#endif

#ifdef PERL_OBJECT

#ifndef PerlIO
typedef struct _PerlIO PerlIO;
#endif

/* IPerlStdIO		*/
struct IPerlStdIO;
typedef PerlIO*		(*LPStdin)(struct IPerlStdIO*);
typedef PerlIO*		(*LPStdout)(struct IPerlStdIO*);
typedef PerlIO*		(*LPStderr)(struct IPerlStdIO*);
typedef PerlIO*		(*LPOpen)(struct IPerlStdIO*, const char*,
			    const char*);
typedef int		(*LPClose)(struct IPerlStdIO*, PerlIO*);
typedef int		(*LPEof)(struct IPerlStdIO*, PerlIO*);
typedef int		(*LPError)(struct IPerlStdIO*, PerlIO*);
typedef void		(*LPClearerr)(struct IPerlStdIO*, PerlIO*);
typedef int		(*LPGetc)(struct IPerlStdIO*, PerlIO*);
typedef char*		(*LPGetBase)(struct IPerlStdIO*, PerlIO*);
typedef int		(*LPGetBufsiz)(struct IPerlStdIO*, PerlIO*);
typedef int		(*LPGetCnt)(struct IPerlStdIO*, PerlIO*);
typedef char*		(*LPGetPtr)(struct IPerlStdIO*, PerlIO*);
typedef char*		(*LPGets)(struct IPerlStdIO*, PerlIO*, char*, int);
typedef int		(*LPPutc)(struct IPerlStdIO*, PerlIO*, int);
typedef int		(*LPPuts)(struct IPerlStdIO*, PerlIO*, const char*);
typedef int		(*LPFlush)(struct IPerlStdIO*, PerlIO*);
typedef int		(*LPUngetc)(struct IPerlStdIO*, PerlIO*,int);
typedef int		(*LPFileno)(struct IPerlStdIO*, PerlIO*);
typedef PerlIO*		(*LPFdopen)(struct IPerlStdIO*, int, const char*);
typedef PerlIO*		(*LPReopen)(struct IPerlStdIO*, const char*,
			    const char*, PerlIO*);
typedef SSize_t		(*LPRead)(struct IPerlStdIO*, PerlIO*, void*, Size_t);
typedef SSize_t		(*LPWrite)(struct IPerlStdIO*, PerlIO*, const void*,
			    Size_t);
typedef void		(*LPSetBuf)(struct IPerlStdIO*, PerlIO*, char*);
typedef int		(*LPSetVBuf)(struct IPerlStdIO*, PerlIO*, char*, int,
			    Size_t);
typedef void		(*LPSetCnt)(struct IPerlStdIO*, PerlIO*, int);
typedef void		(*LPSetPtrCnt)(struct IPerlStdIO*, PerlIO*, char*,
			    int);
typedef void		(*LPSetlinebuf)(struct IPerlStdIO*, PerlIO*);
typedef int		(*LPPrintf)(struct IPerlStdIO*, PerlIO*, const char*, 
			    ...);
typedef int		(*LPVprintf)(struct IPerlStdIO*, PerlIO*, const char*,
			    va_list);
typedef long		(*LPTell)(struct IPerlStdIO*, PerlIO*);
typedef int		(*LPSeek)(struct IPerlStdIO*, PerlIO*, Off_t, int);
typedef void		(*LPRewind)(struct IPerlStdIO*, PerlIO*);
typedef PerlIO*		(*LPTmpfile)(struct IPerlStdIO*);
typedef int		(*LPGetpos)(struct IPerlStdIO*, PerlIO*, Fpos_t*);
typedef int		(*LPSetpos)(struct IPerlStdIO*, PerlIO*,
			    const Fpos_t*);
typedef void		(*LPInit)(struct IPerlStdIO*);
typedef void		(*LPInitOSExtras)(struct IPerlStdIO*);

struct IPerlStdIO
{
    LPStdin		pStdin;
    LPStdout		pStdout;
    LPStderr		pStderr;
    LPOpen		pOpen;
    LPClose		pClose;
    LPEof		pEof;
    LPError		pError;
    LPClearerr		pClearerr;
    LPGetc		pGetc;
    LPGetBase		pGetBase;
    LPGetBufsiz		pGetBufsiz;
    LPGetCnt		pGetCnt;
    LPGetPtr		pGetPtr;
    LPGets		pGets;
    LPPutc		pPutc;
    LPPuts		pPuts;
    LPFlush		pFlush;
    LPUngetc		pUngetc;
    LPFileno		pFileno;
    LPFdopen		pFdopen;
    LPReopen		pReopen;
    LPRead		pRead;
    LPWrite		pWrite;
    LPSetBuf		pSetBuf;
    LPSetVBuf		pSetVBuf;
    LPSetCnt		pSetCnt;
    LPSetPtrCnt		pSetPtrCnt;
    LPSetlinebuf	pSetlinebuf;
    LPPrintf		pPrintf;
    LPVprintf		pVprintf;
    LPTell		pTell;
    LPSeek		pSeek;
    LPRewind		pRewind;
    LPTmpfile		pTmpfile;
    LPGetpos		pGetpos;
    LPSetpos		pSetpos;
    LPInit		pInit;
    LPInitOSExtras	pInitOSExtras;
};

struct IPerlStdIOInfo
{
    unsigned long	nCount;	    /* number of entries expected */
    struct IPerlStdIO	perlStdIOList;
};

#ifdef USE_STDIO_PTR
#  define PerlIO_has_cntptr(f)		1       
#  ifdef STDIO_CNT_LVALUE
#    define PerlIO_canset_cnt(f)	1      
#    ifdef STDIO_PTR_LVALUE
#      define PerlIO_fast_gets(f)	1        
#    endif
#  else
#    define PerlIO_canset_cnt(f)	0      
#  endif
#else  /* USE_STDIO_PTR */
#  define PerlIO_has_cntptr(f)		0
#  define PerlIO_canset_cnt(f)		0
#endif /* USE_STDIO_PTR */

#ifndef PerlIO_fast_gets
#define PerlIO_fast_gets(f)		0        
#endif

#ifdef FILE_base
#define PerlIO_has_base(f)		1
#else
#define PerlIO_has_base(f)		0
#endif

#define PerlIO_stdin()							\
	(*PL_piStdIO->pStdin)(PL_piStdIO)
#define PerlIO_stdout()							\
	(*PL_piStdIO->pStdout)(PL_piStdIO)
#define PerlIO_stderr()							\
	(*PL_piStdIO->pStderr)(PL_piStdIO)
#define PerlIO_open(x,y)						\
	(*PL_piStdIO->pOpen)(PL_piStdIO, (x),(y))
#define PerlIO_close(f)							\
	(*PL_piStdIO->pClose)(PL_piStdIO, (f))
#define PerlIO_eof(f)							\
	(*PL_piStdIO->pEof)(PL_piStdIO, (f))
#define PerlIO_error(f)							\
	(*PL_piStdIO->pError)(PL_piStdIO, (f))
#define PerlIO_clearerr(f)						\
	(*PL_piStdIO->pClearerr)(PL_piStdIO, (f))
#define PerlIO_getc(f)							\
	(*PL_piStdIO->pGetc)(PL_piStdIO, (f))
#define PerlIO_get_base(f)						\
	(*PL_piStdIO->pGetBase)(PL_piStdIO, (f))
#define PerlIO_get_bufsiz(f)						\
	(*PL_piStdIO->pGetBufsiz)(PL_piStdIO, (f))
#define PerlIO_get_cnt(f)						\
	(*PL_piStdIO->pGetCnt)(PL_piStdIO, (f))
#define PerlIO_get_ptr(f)						\
	(*PL_piStdIO->pGetPtr)(PL_piStdIO, (f))
#define PerlIO_putc(f,c)						\
	(*PL_piStdIO->pPutc)(PL_piStdIO, (f),(c))
#define PerlIO_puts(f,s)						\
	(*PL_piStdIO->pPuts)(PL_piStdIO, (f),(s))
#define PerlIO_flush(f)							\
	(*PL_piStdIO->pFlush)(PL_piStdIO, (f))
#define PerlIO_gets(s, n, fp)						\
	(*PL_piStdIO->pGets)(PL_piStdIO, (fp), s, n)
#define PerlIO_ungetc(f,c)						\
	(*PL_piStdIO->pUngetc)(PL_piStdIO, (f),(c))
#define PerlIO_fileno(f)						\
	(*PL_piStdIO->pFileno)(PL_piStdIO, (f))
#define PerlIO_fdopen(f, s)						\
	(*PL_piStdIO->pFdopen)(PL_piStdIO, (f),(s))
#define PerlIO_reopen(p, m, f)						\
	(*PL_piStdIO->pReopen)(PL_piStdIO, (p), (m), (f))
#define PerlIO_read(f,buf,count)					\
	(SSize_t)(*PL_piStdIO->pRead)(PL_piStdIO, (f), (buf), (count))
#define PerlIO_write(f,buf,count)					\
	(*PL_piStdIO->pWrite)(PL_piStdIO, (f), (buf), (count))
#define PerlIO_setbuf(f,b)						\
	(*PL_piStdIO->pSetBuf)(PL_piStdIO, (f), (b))
#define PerlIO_setvbuf(f,b,t,s)						\
	(*PL_piStdIO->pSetVBuf)(PL_piStdIO, (f),(b),(t),(s))
#define PerlIO_set_cnt(f,c)						\
	(*PL_piStdIO->pSetCnt)(PL_piStdIO, (f), (c))
#define PerlIO_set_ptrcnt(f,p,c)					\
	(*PL_piStdIO->pSetPtrCnt)(PL_piStdIO, (f), (p), (c))
#define PerlIO_setlinebuf(f)						\
	(*PL_piStdIO->pSetlinebuf)(PL_piStdIO, (f))
#define PerlIO_printf		fprintf
#define PerlIO_stdoutf		*PL_piStdIO->pPrintf
#define PerlIO_vprintf(f,fmt,a)						\
	(*PL_piStdIO->pVprintf)(PL_piStdIO, (f),(fmt),a)          
#define PerlIO_tell(f)							\
	(*PL_piStdIO->pTell)(PL_piStdIO, (f))
#define PerlIO_seek(f,o,w)						\
	(*PL_piStdIO->pSeek)(PL_piStdIO, (f),(o),(w))
#define PerlIO_getpos(f,p)						\
	(*PL_piStdIO->pGetpos)(PL_piStdIO, (f),(p))
#define PerlIO_setpos(f,p)						\
	(*PL_piStdIO->pSetpos)(PL_piStdIO, (f),(p))
#define PerlIO_rewind(f)						\
	(*PL_piStdIO->pRewind)(PL_piStdIO, (f))
#define PerlIO_tmpfile()						\
	(*PL_piStdIO->pTmpfile)(PL_piStdIO)
#define PerlIO_init()							\
	(*PL_piStdIO->pInit)(PL_piStdIO)
#undef 	init_os_extras
#define init_os_extras(x)						\
	(*PL_piStdIO->pInitOSExtras)(PL_piStdIO)

#else	/* PERL_OBJECT */

#include "perlsdio.h"

#endif	/* PERL_OBJECT */

#ifndef PERLIO_IS_STDIO
#ifdef USE_SFIO
#include "perlsfio.h"
#endif /* USE_SFIO */
#endif /* PERLIO_IS_STDIO */

#ifndef EOF
#define EOF (-1)
#endif

/* This is to catch case with no stdio */
#ifndef BUFSIZ
#define BUFSIZ 1024
#endif

#ifndef SEEK_SET
#define SEEK_SET 0
#endif

#ifndef SEEK_CUR
#define SEEK_CUR 1
#endif

#ifndef SEEK_END
#define SEEK_END 2
#endif

#ifndef PerlIO
struct _PerlIO;
#define PerlIO struct _PerlIO
#endif /* No PerlIO */

#ifndef Fpos_t
#define Fpos_t long
#endif

#ifndef NEXT30_NO_ATTRIBUTE
#ifndef HASATTRIBUTE       /* disable GNU-cc attribute checking? */
#ifdef  __attribute__      /* Avoid possible redefinition errors */
#undef  __attribute__
#endif
#define __attribute__(attr)
#endif
#endif

#ifndef PerlIO_stdoutf
extern int	PerlIO_stdoutf		(const char *,...)
					__attribute__((format (printf, 1, 2)));
#endif
#ifndef PerlIO_puts
extern int	PerlIO_puts		(PerlIO *,const char *);
#endif
#ifndef PerlIO_open
extern PerlIO *	PerlIO_open		(const char *,const char *);
#endif
#ifndef PerlIO_close
extern int	PerlIO_close		(PerlIO *);
#endif
#ifndef PerlIO_eof
extern int	PerlIO_eof		(PerlIO *);
#endif
#ifndef PerlIO_error
extern int	PerlIO_error		(PerlIO *);
#endif
#ifndef PerlIO_clearerr
extern void	PerlIO_clearerr		(PerlIO *);
#endif
#ifndef PerlIO_getc
extern int	PerlIO_getc		(PerlIO *);
#endif
#ifndef PerlIO_putc
extern int	PerlIO_putc		(PerlIO *,int);
#endif
#ifndef PerlIO_flush
extern int	PerlIO_flush		(PerlIO *);
#endif
#ifndef PerlIO_ungetc
extern int	PerlIO_ungetc		(PerlIO *,int);
#endif
#ifndef PerlIO_fileno
extern int	PerlIO_fileno		(PerlIO *);
#endif
#ifndef PerlIO_fdopen
extern PerlIO *	PerlIO_fdopen		(int, const char *);
#endif
#ifndef PerlIO_importFILE
extern PerlIO *	PerlIO_importFILE	(FILE *,int);
#endif
#ifndef PerlIO_exportFILE
extern FILE *	PerlIO_exportFILE	(PerlIO *,int);
#endif
#ifndef PerlIO_findFILE
extern FILE *	PerlIO_findFILE		(PerlIO *);
#endif
#ifndef PerlIO_releaseFILE
extern void	PerlIO_releaseFILE	(PerlIO *,FILE *);
#endif
#ifndef PerlIO_read
extern SSize_t	PerlIO_read		(PerlIO *,void *,Size_t);
#endif
#ifndef PerlIO_write
extern SSize_t	PerlIO_write		(PerlIO *,const void *,Size_t);
#endif
#ifndef PerlIO_setlinebuf
extern void	PerlIO_setlinebuf	(PerlIO *);
#endif
#ifndef PerlIO_printf
extern int	PerlIO_printf		(PerlIO *, const char *,...)
					__attribute__((format (printf, 2, 3)));
#endif
#ifndef PerlIO_sprintf
extern int	PerlIO_sprintf		(char *, int, const char *,...)
					__attribute__((format (printf, 3, 4)));
#endif
#ifndef PerlIO_vprintf
extern int	PerlIO_vprintf		(PerlIO *, const char *, va_list);
#endif
#ifndef PerlIO_tell
extern Off_t	PerlIO_tell		(PerlIO *);
#endif
#ifndef PerlIO_seek
extern int	PerlIO_seek		(PerlIO *, Off_t, int);
#endif
#ifndef PerlIO_rewind
extern void	PerlIO_rewind		(PerlIO *);
#endif
#ifndef PerlIO_has_base
extern int	PerlIO_has_base		(PerlIO *);
#endif
#ifndef PerlIO_has_cntptr
extern int	PerlIO_has_cntptr	(PerlIO *);
#endif
#ifndef PerlIO_fast_gets
extern int	PerlIO_fast_gets	(PerlIO *);
#endif
#ifndef PerlIO_canset_cnt
extern int	PerlIO_canset_cnt	(PerlIO *);
#endif
#ifndef PerlIO_get_ptr
extern STDCHAR * PerlIO_get_ptr		(PerlIO *);
#endif
#ifndef PerlIO_get_cnt
extern int	PerlIO_get_cnt		(PerlIO *);
#endif
#ifndef PerlIO_set_cnt
extern void	PerlIO_set_cnt		(PerlIO *,int);
#endif
#ifndef PerlIO_set_ptrcnt
extern void	PerlIO_set_ptrcnt	(PerlIO *,STDCHAR *,int);
#endif
#ifndef PerlIO_get_base
extern STDCHAR * PerlIO_get_base	(PerlIO *);
#endif
#ifndef PerlIO_get_bufsiz
extern int	PerlIO_get_bufsiz	(PerlIO *);
#endif
#ifndef PerlIO_tmpfile
extern PerlIO *	PerlIO_tmpfile		(void);
#endif
#ifndef PerlIO_stdin
extern PerlIO *	PerlIO_stdin	(void);
#endif
#ifndef PerlIO_stdout
extern PerlIO *	PerlIO_stdout	(void);
#endif
#ifndef PerlIO_stderr
extern PerlIO *	PerlIO_stderr	(void);
#endif
#ifndef PerlIO_getpos
extern int	PerlIO_getpos		(PerlIO *,Fpos_t *);
#endif
#ifndef PerlIO_setpos
extern int	PerlIO_setpos		(PerlIO *,const Fpos_t *);
#endif


/*
 *   Interface for directory functions
 */

#ifdef PERL_OBJECT

/* IPerlDir		*/
struct IPerlDir;
typedef int		(*LPMakedir)(struct IPerlDir*, const char*, int);
typedef int		(*LPChdir)(struct IPerlDir*, const char*);
typedef int		(*LPRmdir)(struct IPerlDir*, const char*);
typedef int		(*LPDirClose)(struct IPerlDir*, DIR*);
typedef DIR*		(*LPDirOpen)(struct IPerlDir*, char*);
typedef struct direct*	(*LPDirRead)(struct IPerlDir*, DIR*);
typedef void		(*LPDirRewind)(struct IPerlDir*, DIR*);
typedef void		(*LPDirSeek)(struct IPerlDir*, DIR*, long);
typedef long		(*LPDirTell)(struct IPerlDir*, DIR*);

struct IPerlDir
{
    LPMakedir		pMakedir;
    LPChdir		pChdir;
    LPRmdir		pRmdir;
    LPDirClose		pClose;
    LPDirOpen		pOpen;
    LPDirRead		pRead;
    LPDirRewind		pRewind;
    LPDirSeek		pSeek;
    LPDirTell		pTell;
};

struct IPerlDirInfo
{
    unsigned long	nCount;	    /* number of entries expected */
    struct IPerlDir	perlDirList;
};

#define PerlDir_mkdir(name, mode)				\
	(*PL_piDir->pMakedir)(PL_piDir, (name), (mode))
#define PerlDir_chdir(name)					\
	(*PL_piDir->pChdir)(PL_piDir, (name))
#define PerlDir_rmdir(name)					\
	(*PL_piDir->pRmdir)(PL_piDir, (name))
#define PerlDir_close(dir)					\
	(*PL_piDir->pClose)(PL_piDir, (dir))
#define PerlDir_open(name)					\
	(*PL_piDir->pOpen)(PL_piDir, (name))
#define PerlDir_read(dir)					\
	(*PL_piDir->pRead)(PL_piDir, (dir))
#define PerlDir_rewind(dir)					\
	(*PL_piDir->pRewind)(PL_piDir, (dir))
#define PerlDir_seek(dir, loc)					\
	(*PL_piDir->pSeek)(PL_piDir, (dir), (loc))
#define PerlDir_tell(dir)					\
	(*PL_piDir->pTell)(PL_piDir, (dir))

#else	/* PERL_OBJECT */

#define PerlDir_mkdir(name, mode)	Mkdir((name), (mode))
#ifdef VMS
#  define PerlDir_chdir(n)		chdir(((n) && *(n)) ? (n) : "SYS$LOGIN")
#else 
#  define PerlDir_chdir(name)		chdir((name))
#endif
#define PerlDir_rmdir(name)		rmdir((name))
#define PerlDir_close(dir)		closedir((dir))
#define PerlDir_open(name)		opendir((name))
#define PerlDir_read(dir)		readdir((dir))
#define PerlDir_rewind(dir)		rewinddir((dir))
#define PerlDir_seek(dir, loc)		seekdir((dir), (loc))
#define PerlDir_tell(dir)		telldir((dir))

#endif	/* PERL_OBJECT */

/*
    Interface for perl environment functions
*/

#ifdef PERL_OBJECT

/* IPerlEnv		*/
struct IPerlEnv;
typedef char*		(*LPEnvGetenv)(struct IPerlEnv*, const char*);
typedef int		(*LPEnvPutenv)(struct IPerlEnv*, const char*);
typedef char *		(*LPEnvGetenv_len)(struct IPerlEnv*,
				    const char *varname, unsigned long *len);
typedef int		(*LPEnvUname)(struct IPerlEnv*, struct utsname *name);
typedef void		(*LPEnvClearenv)(struct IPerlEnv*);
typedef unsigned long	(*LPEnvOsID)(struct IPerlEnv*);
#ifdef HAS_ENVGETENV
typedef char *		(*LPENVGetenv)(struct IPerlEnv*, const char *varname);
typedef char *		(*LPENVGetenv_len)(struct IPerlEnv*,
				    const char *varname, unsigned long *len);
#endif
#ifdef WIN32
typedef char*		(*LPEnvLibPath)(struct IPerlEnv*, char*);
typedef char*		(*LPEnvSiteLibPath)(struct IPerlEnv*, char*);
#endif

struct IPerlEnv
{
    LPEnvGetenv		pGetenv;
    LPEnvPutenv		pPutenv;
    LPEnvGetenv_len	pGetenv_len;
    LPEnvUname		pEnvUname;
    LPEnvClearenv	pClearenv;
#ifdef HAS_ENVGETENV
    LPENVGetenv		pENVGetenv;
    LPENVGetenv_len	pENVGetenv_len;
#endif
#ifdef WIN32
    LPEnvOsID		pEnvOsID;
    LPEnvLibPath	pLibPath;
    LPEnvSiteLibPath	pSiteLibPath;
#endif
};

struct IPerlEnvInfo
{
    unsigned long	nCount;	    /* number of entries expected */
    struct IPerlEnv	perlEnvList;
};

#define PerlEnv_putenv(str)					\
	(*PL_piENV->pPutenv)(PL_piENV,(str))
#define PerlEnv_getenv(str)					\
	(*PL_piENV->pGetenv)(PL_piENV,(str))
#define PerlEnv_getenv_len(str,l)				\
	(*PL_piENV->pGetenv_len)(PL_piENV,(str), (l))
#define PerlEnv_Clear()						\
	(*PL_piENV->pClearenv)(PL_piENV)
#define PerlEnv_Clear()						\
	(*PL_piENV->pClearenv)(PL_piENV)
#ifdef HAS_ENVGETENV
#  define PerlEnv_ENVgetenv(str)				\
	(*PL_piENV->pENVGetenv)(PL_piENV,(str))
#  define PerlEnv_ENVgetenv_len(str,l)				\
	(*PL_piENV->pENVGetenv_len)(PL_piENV,(str), (l))
#else
#  define PerlEnv_ENVgetenv(str)				\
	PerlEnv_getenv((str))
#  define PerlEnv_ENVgetenv_len(str,l)				\
	PerlEnv_getenv_len((str),(l))
#endif
#define PerlEnv_uname(name)					\
	(*PL_piENV->pEnvUname)(PL_piENV,(name))
#ifdef WIN32
#define PerlEnv_os_id()						\
	(*PL_piENV->pEnvOsID)(PL_piENV)
#define PerlEnv_lib_path(str)					\
	(*PL_piENV->pLibPath)(PL_piENV,(str))
#define PerlEnv_sitelib_path(str)				\
	(*PL_piENV->pSiteLibPath)(PL_piENV,(str))
#endif

#else	/* PERL_OBJECT */

#define PerlEnv_putenv(str)		putenv((str))
#define PerlEnv_getenv(str)		getenv((str))
#define PerlEnv_getenv_len(str,l)	getenv_len((str), (l))
#ifdef HAS_ENVGETENV
#  define PerlEnv_ENVgetenv(str)	ENVgetenv((str))
#  define PerlEnv_ENVgetenv_len(str,l)	ENVgetenv_len((str), (l))
#else
#  define PerlEnv_ENVgetenv(str)	PerlEnv_getenv((str))
#  define PerlEnv_ENVgetenv_len(str,l)	PerlEnv_getenv_len((str), (l))
#endif
#define PerlEnv_uname(name)		uname((name))

#ifdef WIN32
#define PerlEnv_os_id()			win32_os_id()
#endif

#endif	/* PERL_OBJECT */

/*
    Interface for perl low-level IO functions
*/

#ifdef PERL_OBJECT

/* IPerlLIO		*/
struct IPerlLIO;
typedef int		(*LPLIOAccess)(struct IPerlLIO*, const char*, int);
typedef int		(*LPLIOChmod)(struct IPerlLIO*, const char*, int);
typedef int		(*LPLIOChown)(struct IPerlLIO*, const char*, uid_t,
			    gid_t);
typedef int		(*LPLIOChsize)(struct IPerlLIO*, int, long);
typedef int		(*LPLIOClose)(struct IPerlLIO*, int);
typedef int		(*LPLIODup)(struct IPerlLIO*, int);
typedef int		(*LPLIODup2)(struct IPerlLIO*, int, int);
typedef int		(*LPLIOFlock)(struct IPerlLIO*, int, int);
typedef int		(*LPLIOFileStat)(struct IPerlLIO*, int, struct stat*);
typedef int		(*LPLIOIOCtl)(struct IPerlLIO*, int, unsigned int,
			    char*);
typedef int		(*LPLIOIsatty)(struct IPerlLIO*, int);
typedef long		(*LPLIOLseek)(struct IPerlLIO*, int, long, int);
typedef int		(*LPLIOLstat)(struct IPerlLIO*, const char*,
			    struct stat*);
typedef char*		(*LPLIOMktemp)(struct IPerlLIO*, char*);
typedef int		(*LPLIOOpen)(struct IPerlLIO*, const char*, int);	
typedef int		(*LPLIOOpen3)(struct IPerlLIO*, const char*, int, int);	
typedef int		(*LPLIORead)(struct IPerlLIO*, int, void*, unsigned int);
typedef int		(*LPLIORename)(struct IPerlLIO*, const char*,
			    const char*);
typedef int		(*LPLIOSetmode)(struct IPerlLIO*, int, int);
typedef int		(*LPLIONameStat)(struct IPerlLIO*, const char*,
			    struct stat*);
typedef char*		(*LPLIOTmpnam)(struct IPerlLIO*, char*);
typedef int		(*LPLIOUmask)(struct IPerlLIO*, int);
typedef int		(*LPLIOUnlink)(struct IPerlLIO*, const char*);
typedef int		(*LPLIOUtime)(struct IPerlLIO*, char*, struct utimbuf*);
typedef int		(*LPLIOWrite)(struct IPerlLIO*, int, const void*,
			    unsigned int);

struct IPerlLIO
{
    LPLIOAccess		pAccess;
    LPLIOChmod		pChmod;
    LPLIOChown		pChown;
    LPLIOChsize		pChsize;
    LPLIOClose		pClose;
    LPLIODup		pDup;
    LPLIODup2		pDup2;
    LPLIOFlock		pFlock;
    LPLIOFileStat	pFileStat;
    LPLIOIOCtl		pIOCtl;
    LPLIOIsatty		pIsatty;
    LPLIOLseek		pLseek;
    LPLIOLstat		pLstat;
    LPLIOMktemp		pMktemp;
    LPLIOOpen		pOpen;
    LPLIOOpen3		pOpen3;
    LPLIORead		pRead;
    LPLIORename		pRename;
    LPLIOSetmode	pSetmode;
    LPLIONameStat	pNameStat;
    LPLIOTmpnam		pTmpnam;
    LPLIOUmask		pUmask;
    LPLIOUnlink		pUnlink;
    LPLIOUtime		pUtime;
    LPLIOWrite		pWrite;
};

struct IPerlLIOInfo
{
    unsigned long	nCount;	    /* number of entries expected */
    struct IPerlLIO	perlLIOList;
};

#define PerlLIO_access(file, mode)					\
	(*PL_piLIO->pAccess)(PL_piLIO, (file), (mode))
#define PerlLIO_chmod(file, mode)					\
	(*PL_piLIO->pChmod)(PL_piLIO, (file), (mode))
#define PerlLIO_chown(file, owner, group)				\
	(*PL_piLIO->pChown)(PL_piLIO, (file), (owner), (group))
#define PerlLIO_chsize(fd, size)					\
	(*PL_piLIO->pChsize)(PL_piLIO, (fd), (size))
#define PerlLIO_close(fd)						\
	(*PL_piLIO->pClose)(PL_piLIO, (fd))
#define PerlLIO_dup(fd)							\
	(*PL_piLIO->pDup)(PL_piLIO, (fd))
#define PerlLIO_dup2(fd1, fd2)						\
	(*PL_piLIO->pDup2)(PL_piLIO, (fd1), (fd2))
#define PerlLIO_flock(fd, op)						\
	(*PL_piLIO->pFlock)(PL_piLIO, (fd), (op))
#define PerlLIO_fstat(fd, buf)						\
	(*PL_piLIO->pFileStat)(PL_piLIO, (fd), (buf))
#define PerlLIO_ioctl(fd, u, buf)					\
	(*PL_piLIO->pIOCtl)(PL_piLIO, (fd), (u), (buf))
#define PerlLIO_isatty(fd)						\
	(*PL_piLIO->pIsatty)(PL_piLIO, (fd))
#define PerlLIO_lseek(fd, offset, mode)					\
	(*PL_piLIO->pLseek)(PL_piLIO, (fd), (offset), (mode))
#define PerlLIO_lstat(name, buf)					\
	(*PL_piLIO->pLstat)(PL_piLIO, (name), (buf))
#define PerlLIO_mktemp(file)						\
	(*PL_piLIO->pMktemp)(PL_piLIO, (file))
#define PerlLIO_open(file, flag)					\
	(*PL_piLIO->pOpen)(PL_piLIO, (file), (flag))
#define PerlLIO_open3(file, flag, perm)					\
	(*PL_piLIO->pOpen3)(PL_piLIO, (file), (flag), (perm))
#define PerlLIO_read(fd, buf, count)					\
	(*PL_piLIO->pRead)(PL_piLIO, (fd), (buf), (count))
#define PerlLIO_rename(oname, newname)					\
	(*PL_piLIO->pRename)(PL_piLIO, (oname), (newname))
#define PerlLIO_setmode(fd, mode)					\
	(*PL_piLIO->pSetmode)(PL_piLIO, (fd), (mode))
#define PerlLIO_stat(name, buf)						\
	(*PL_piLIO->pNameStat)(PL_piLIO, (name), (buf))
#define PerlLIO_tmpnam(str)						\
	(*PL_piLIO->pTmpnam)(PL_piLIO, (str))
#define PerlLIO_umask(mode)						\
	(*PL_piLIO->pUmask)(PL_piLIO, (mode))
#define PerlLIO_unlink(file)						\
	(*PL_piLIO->pUnlink)(PL_piLIO, (file))
#define PerlLIO_utime(file, time)					\
	(*PL_piLIO->pUtime)(PL_piLIO, (file), (time))
#define PerlLIO_write(fd, buf, count)					\
	(*PL_piLIO->pWrite)(PL_piLIO, (fd), (buf), (count))

#else	/* PERL_OBJECT */

#define PerlLIO_access(file, mode)	access((file), (mode))
#define PerlLIO_chmod(file, mode)	chmod((file), (mode))
#define PerlLIO_chown(file, owner, grp)	chown((file), (owner), (grp))
#define PerlLIO_chsize(fd, size)	chsize((fd), (size))
#define PerlLIO_close(fd)		close((fd))
#define PerlLIO_dup(fd)			dup((fd))
#define PerlLIO_dup2(fd1, fd2)		dup2((fd1), (fd2))
#define PerlLIO_flock(fd, op)		FLOCK((fd), (op))
#define PerlLIO_fstat(fd, buf)		Fstat((fd), (buf))
#define PerlLIO_ioctl(fd, u, buf)	ioctl((fd), (u), (buf))
#define PerlLIO_isatty(fd)		isatty((fd))
#define PerlLIO_lseek(fd, offset, mode)	lseek((fd), (offset), (mode))
#ifdef HAS_LSTAT
#define PerlLIO_lstat(name, buf)	lstat((name), (buf))
#else
#define PerlLIO_lstat(name, buf)	PerlLIO_stat((name), (buf))
#endif
#define PerlLIO_mktemp(file)		mktemp((file))
#define PerlLIO_mkstemp(file)		mkstemp((file))
#define PerlLIO_open(file, flag)	open((file), (flag))
#define PerlLIO_open3(file, flag, perm)	open((file), (flag), (perm))
#define PerlLIO_read(fd, buf, count)	read((fd), (buf), (count))
#define PerlLIO_rename(old, new)	rename((old), (new))
#define PerlLIO_setmode(fd, mode)	setmode((fd), (mode))
#define PerlLIO_stat(name, buf)		Stat((name), (buf))
#define PerlLIO_tmpnam(str)		tmpnam((str))
#define PerlLIO_umask(mode)		umask((mode))
#define PerlLIO_unlink(file)		unlink((file))
#define PerlLIO_utime(file, time)	utime((file), (time))
#define PerlLIO_write(fd, buf, count)	write((fd), (buf), (count))

#endif	/* PERL_OBJECT */

/*
    Interface for perl memory allocation
*/

#ifdef PERL_OBJECT

/* IPerlMem		*/
struct IPerlMem;
typedef void*		(*LPMemMalloc)(struct IPerlMem*, size_t);
typedef void*		(*LPMemRealloc)(struct IPerlMem*, void*, size_t);
typedef void		(*LPMemFree)(struct IPerlMem*, void*);

struct IPerlMem
{
    LPMemMalloc		pMalloc;
    LPMemRealloc	pRealloc;
    LPMemFree		pFree;
};

struct IPerlMemInfo
{
    unsigned long	nCount;	    /* number of entries expected */
    struct IPerlMem	perlMemList;
};

#define PerlMem_malloc(size)				    \
	(*PL_piMem->pMalloc)(PL_piMem, (size))
#define PerlMem_realloc(buf, size)			    \
	(*PL_piMem->pRealloc)(PL_piMem, (buf), (size))
#define PerlMem_free(buf)				    \
	(*PL_piMem->pFree)(PL_piMem, (buf))

#else	/* PERL_OBJECT */

#define PerlMem_malloc(size)		malloc((size))
#define PerlMem_realloc(buf, size)	realloc((buf), (size))
#define PerlMem_free(buf)		free((buf))

#endif	/* PERL_OBJECT */

/*
    Interface for perl process functions
*/


#ifdef PERL_OBJECT

#ifndef Sighandler_t
typedef Signal_t (*Sighandler_t) (int);
#endif
#ifndef jmp_buf
#include <setjmp.h>
#endif

/* IPerlProc		*/
struct IPerlProc;
typedef void		(*LPProcAbort)(struct IPerlProc*);
typedef char*		(*LPProcCrypt)(struct IPerlProc*, const char*,
			    const char*);
typedef void		(*LPProcExit)(struct IPerlProc*, int);
typedef void		(*LPProc_Exit)(struct IPerlProc*, int);
typedef int		(*LPProcExecl)(struct IPerlProc*, const char*,
			    const char*, const char*, const char*,
			    const char*);
typedef int		(*LPProcExecv)(struct IPerlProc*, const char*,
			    const char*const*);
typedef int		(*LPProcExecvp)(struct IPerlProc*, const char*,
			    const char*const*);
typedef uid_t		(*LPProcGetuid)(struct IPerlProc*);
typedef uid_t		(*LPProcGeteuid)(struct IPerlProc*);
typedef gid_t		(*LPProcGetgid)(struct IPerlProc*);
typedef gid_t		(*LPProcGetegid)(struct IPerlProc*);
typedef char*		(*LPProcGetlogin)(struct IPerlProc*);
typedef int		(*LPProcKill)(struct IPerlProc*, int, int);
typedef int		(*LPProcKillpg)(struct IPerlProc*, int, int);
typedef int		(*LPProcPauseProc)(struct IPerlProc*);
typedef PerlIO*		(*LPProcPopen)(struct IPerlProc*, const char*,
			    const char*);
typedef int		(*LPProcPclose)(struct IPerlProc*, PerlIO*);
typedef int		(*LPProcPipe)(struct IPerlProc*, int*);
typedef int		(*LPProcSetuid)(struct IPerlProc*, uid_t);
typedef int		(*LPProcSetgid)(struct IPerlProc*, gid_t);
typedef int		(*LPProcSleep)(struct IPerlProc*, unsigned int);
typedef int		(*LPProcTimes)(struct IPerlProc*, struct tms*);
typedef int		(*LPProcWait)(struct IPerlProc*, int*);
typedef int		(*LPProcWaitpid)(struct IPerlProc*, int, int*, int);
typedef Sighandler_t	(*LPProcSignal)(struct IPerlProc*, int, Sighandler_t);
typedef void*		(*LPProcDynaLoader)(struct IPerlProc*, const char*);
#ifdef WIN32
typedef void		(*LPProcGetOSError)(struct IPerlProc*,
			    SV* sv, DWORD dwErr);
typedef void		(*LPProcFreeBuf)(struct IPerlProc*, char*);
typedef BOOL		(*LPProcDoCmd)(struct IPerlProc*, char*);
typedef int		(*LPProcSpawn)(struct IPerlProc*, char*);
typedef int		(*LPProcSpawnvp)(struct IPerlProc*, int, const char*,
			    const char*const*);
typedef int		(*LPProcASpawn)(struct IPerlProc*, void*, void**, void**);
#endif

struct IPerlProc
{
    LPProcAbort		pAbort;
    LPProcCrypt		pCrypt;
    LPProcExit		pExit;
    LPProc_Exit		p_Exit;
    LPProcExecl		pExecl;
    LPProcExecv		pExecv;
    LPProcExecvp	pExecvp;
    LPProcGetuid	pGetuid;
    LPProcGeteuid	pGeteuid;
    LPProcGetgid	pGetgid;
    LPProcGetegid	pGetegid;
    LPProcGetlogin	pGetlogin;
    LPProcKill		pKill;
    LPProcKillpg	pKillpg;
    LPProcPauseProc	pPauseProc;
    LPProcPopen		pPopen;
    LPProcPclose	pPclose;
    LPProcPipe		pPipe;
    LPProcSetuid	pSetuid;
    LPProcSetgid	pSetgid;
    LPProcSleep		pSleep;
    LPProcTimes		pTimes;
    LPProcWait		pWait;
    LPProcWaitpid	pWaitpid;
    LPProcSignal	pSignal;
#ifdef WIN32
    LPProcDynaLoader	pDynaLoader;
    LPProcGetOSError	pGetOSError;
    LPProcDoCmd		pDoCmd;
    LPProcSpawn		pSpawn;
    LPProcSpawnvp	pSpawnvp;
    LPProcASpawn	pASpawn;
#endif
};

struct IPerlProcInfo
{
    unsigned long	nCount;	    /* number of entries expected */
    struct IPerlProc	perlProcList;
};

#define PerlProc_abort()						\
	(*PL_piProc->pAbort)(PL_piProc)
#define PerlProc_crypt(c,s)						\
	(*PL_piProc->pCrypt)(PL_piProc, (c), (s))
#define PerlProc_exit(s)						\
	(*PL_piProc->pExit)(PL_piProc, (s))
#define PerlProc__exit(s)						\
	(*PL_piProc->p_Exit)(PL_piProc, (s))
#define PerlProc_execl(c, w, x, y, z)					\
	(*PL_piProc->pExecl)(PL_piProc, (c), (w), (x), (y), (z))
#define PerlProc_execv(c, a)						\
	(*PL_piProc->pExecv)(PL_piProc, (c), (a))
#define PerlProc_execvp(c, a)						\
	(*PL_piProc->pExecvp)(PL_piProc, (c), (a))
#define PerlProc_getuid()						\
	(*PL_piProc->pGetuid)(PL_piProc)
#define PerlProc_geteuid()						\
	(*PL_piProc->pGeteuid)(PL_piProc)
#define PerlProc_getgid()						\
	(*PL_piProc->pGetgid)(PL_piProc)
#define PerlProc_getegid()						\
	(*PL_piProc->pGetegid)(PL_piProc)
#define PerlProc_getlogin()						\
	(*PL_piProc->pGetlogin)(PL_piProc)
#define PerlProc_kill(i, a)						\
	(*PL_piProc->pKill)(PL_piProc, (i), (a))
#define PerlProc_killpg(i, a)						\
	(*PL_piProc->pKillpg)(PL_piProc, (i), (a))
#define PerlProc_pause()						\
	(*PL_piProc->pPauseProc)(PL_piProc)
#define PerlProc_popen(c, m)						\
	(*PL_piProc->pPopen)(PL_piProc, (c), (m))
#define PerlProc_pclose(f)						\
	(*PL_piProc->pPclose)(PL_piProc, (f))
#define PerlProc_pipe(fd)						\
	(*PL_piProc->pPipe)(PL_piProc, (fd))
#define PerlProc_setuid(u)						\
	(*PL_piProc->pSetuid)(PL_piProc, (u))
#define PerlProc_setgid(g)						\
	(*PL_piProc->pSetgid)(PL_piProc, (g))
#define PerlProc_sleep(t)						\
	(*PL_piProc->pSleep)(PL_piProc, (t))
#define PerlProc_times(t)						\
	(*PL_piProc->pTimes)(PL_piProc, (t))
#define PerlProc_wait(t)						\
	(*PL_piProc->pWait)(PL_piProc, (t))
#define PerlProc_waitpid(p,s,f)						\
	(*PL_piProc->pWaitpid)(PL_piProc, (p), (s), (f))
#define PerlProc_signal(n, h)						\
	(*PL_piProc->pSignal)(PL_piProc, (n), (h))
#define PerlProc_setjmp(b, n) Sigsetjmp((b), (n))
#define PerlProc_longjmp(b, n) Siglongjmp((b), (n))

#ifdef WIN32
#define PerlProc_DynaLoad(f)						\
	(*PL_piProc->pDynaLoader)(PL_piProc, (f))
#define PerlProc_GetOSError(s,e)					\
	(*PL_piProc->pGetOSError)(PL_piProc, (s), (e))
#define PerlProc_Cmd(s)							\
	(*PL_piProc->pDoCmd)(PL_piProc, (s))
#define do_spawn(s)							\
	(*PL_piProc->pSpawn)(PL_piProc, (s))
#define do_spawnvp(m, c, a)						\
	(*PL_piProc->pSpawnvp)(PL_piProc, (m), (c), (a))
#define PerlProc_aspawn(m,c,a)						\
	(*PL_piProc->pASpawn)(PL_piProc, (m), (c), (a))
#endif

#else	/* PERL_OBJECT */

#define PerlProc_abort()	abort()
#define PerlProc_crypt(c,s)	crypt((c), (s))
#define PerlProc_exit(s)	exit((s))
#define PerlProc__exit(s)	_exit((s))
#define PerlProc_execl(c,w,x,y,z)					\
	execl((c), (w), (x), (y), (z))
#define PerlProc_execv(c, a)	execv((c), (a))
#define PerlProc_execvp(c, a)	execvp((c), (a))
#define PerlProc_getuid()	getuid()
#define PerlProc_geteuid()	geteuid()
#define PerlProc_getgid()	getgid()
#define PerlProc_getegid()	getegid()
#define PerlProc_getlogin()	getlogin()
#define PerlProc_kill(i, a)	kill((i), (a))
#define PerlProc_killpg(i, a)	killpg((i), (a))
#define PerlProc_pause()	Pause()
#define PerlProc_popen(c, m)	my_popen((c), (m))
#define PerlProc_pclose(f)	my_pclose((f))
#define PerlProc_pipe(fd)	pipe((fd))
#define PerlProc_setuid(u)	setuid((u))
#define PerlProc_setgid(g)	setgid((g))
#define PerlProc_sleep(t)	sleep((t))
#define PerlProc_times(t)	times((t))
#define PerlProc_wait(t)	wait((t))
#define PerlProc_waitpid(p,s,f)	waitpid((p), (s), (f))
#define PerlProc_setjmp(b, n)	Sigsetjmp((b), (n))
#define PerlProc_longjmp(b, n)	Siglongjmp((b), (n))
#define PerlProc_signal(n, h)	signal((n), (h))

#ifdef WIN32
#define PerlProc_DynaLoad(f)						\
	win32_dynaload(aTHX_ const char*filename)
#define PerlProc_GetOSError(s,e)					\
	win32_str_os_error(aTHX_ (s), (e))
#endif
#endif	/* PERL_OBJECT */

/*
    Interface for perl socket functions
*/

#ifdef PERL_OBJECT

/* PerlSock		*/
struct IPerlSock;
typedef u_long		(*LPHtonl)(struct IPerlSock*, u_long);
typedef u_short		(*LPHtons)(struct IPerlSock*, u_short);
typedef u_long		(*LPNtohl)(struct IPerlSock*, u_long);
typedef u_short		(*LPNtohs)(struct IPerlSock*, u_short);
typedef SOCKET		(*LPAccept)(struct IPerlSock*, SOCKET,
			    struct sockaddr*, int*);
typedef int		(*LPBind)(struct IPerlSock*, SOCKET,
			    const struct sockaddr*, int);
typedef int		(*LPConnect)(struct IPerlSock*, SOCKET,
			    const struct sockaddr*, int);
typedef void		(*LPEndhostent)(struct IPerlSock*);
typedef void		(*LPEndnetent)(struct IPerlSock*);
typedef void		(*LPEndprotoent)(struct IPerlSock*);
typedef void		(*LPEndservent)(struct IPerlSock*);
typedef int		(*LPGethostname)(struct IPerlSock*, char*, int);
typedef int		(*LPGetpeername)(struct IPerlSock*, SOCKET,
			    struct sockaddr*, int*);
typedef struct hostent*	(*LPGethostbyaddr)(struct IPerlSock*, const char*,
			    int, int);
typedef struct hostent*	(*LPGethostbyname)(struct IPerlSock*, const char*);
typedef struct hostent*	(*LPGethostent)(struct IPerlSock*);
typedef struct netent*	(*LPGetnetbyaddr)(struct IPerlSock*, long, int);
typedef struct netent*	(*LPGetnetbyname)(struct IPerlSock*, const char*);
typedef struct netent*	(*LPGetnetent)(struct IPerlSock*);
typedef struct protoent*(*LPGetprotobyname)(struct IPerlSock*, const char*);
typedef struct protoent*(*LPGetprotobynumber)(struct IPerlSock*, int);
typedef struct protoent*(*LPGetprotoent)(struct IPerlSock*);
typedef struct servent*	(*LPGetservbyname)(struct IPerlSock*, const char*,
			    const char*);
typedef struct servent*	(*LPGetservbyport)(struct IPerlSock*, int,
			    const char*);
typedef struct servent*	(*LPGetservent)(struct IPerlSock*);
typedef int		(*LPGetsockname)(struct IPerlSock*, SOCKET,
			    struct sockaddr*, int*);
typedef int		(*LPGetsockopt)(struct IPerlSock*, SOCKET, int, int,
			    char*, int*);
typedef unsigned long	(*LPInetAddr)(struct IPerlSock*, const char*);
typedef char*		(*LPInetNtoa)(struct IPerlSock*, struct in_addr);
typedef int		(*LPListen)(struct IPerlSock*, SOCKET, int);
typedef int		(*LPRecv)(struct IPerlSock*, SOCKET, char*, int, int);
typedef int		(*LPRecvfrom)(struct IPerlSock*, SOCKET, char*, int,
			    int, struct sockaddr*, int*);
typedef int		(*LPSelect)(struct IPerlSock*, int, char*, char*,
			    char*, const struct timeval*);
typedef int		(*LPSend)(struct IPerlSock*, SOCKET, const char*, int,
			    int); 
typedef int		(*LPSendto)(struct IPerlSock*, SOCKET, const char*,
			    int, int, const struct sockaddr*, int);
typedef void		(*LPSethostent)(struct IPerlSock*, int);
typedef void		(*LPSetnetent)(struct IPerlSock*, int);
typedef void		(*LPSetprotoent)(struct IPerlSock*, int);
typedef void		(*LPSetservent)(struct IPerlSock*, int);
typedef int		(*LPSetsockopt)(struct IPerlSock*, SOCKET, int, int,
			    const char*, int);
typedef int		(*LPShutdown)(struct IPerlSock*, SOCKET, int);
typedef SOCKET		(*LPSocket)(struct IPerlSock*, int, int, int);
typedef int		(*LPSocketpair)(struct IPerlSock*, int, int, int,
			    int*);
#ifdef WIN32
typedef int		(*LPClosesocket)(struct IPerlSock*, SOCKET s);
#endif

struct IPerlSock
{
    LPHtonl		pHtonl;
    LPHtons		pHtons;
    LPNtohl		pNtohl;
    LPNtohs		pNtohs;
    LPAccept		pAccept;
    LPBind		pBind;
    LPConnect		pConnect;
    LPEndhostent	pEndhostent;
    LPEndnetent		pEndnetent;
    LPEndprotoent	pEndprotoent;
    LPEndservent	pEndservent;
    LPGethostname	pGethostname;
    LPGetpeername	pGetpeername;
    LPGethostbyaddr	pGethostbyaddr;
    LPGethostbyname	pGethostbyname;
    LPGethostent	pGethostent;
    LPGetnetbyaddr	pGetnetbyaddr;
    LPGetnetbyname	pGetnetbyname;
    LPGetnetent		pGetnetent;
    LPGetprotobyname	pGetprotobyname;
    LPGetprotobynumber	pGetprotobynumber;
    LPGetprotoent	pGetprotoent;
    LPGetservbyname	pGetservbyname;
    LPGetservbyport	pGetservbyport;
    LPGetservent	pGetservent;
    LPGetsockname	pGetsockname;
    LPGetsockopt	pGetsockopt;
    LPInetAddr		pInetAddr;
    LPInetNtoa		pInetNtoa;
    LPListen		pListen;
    LPRecv		pRecv;
    LPRecvfrom		pRecvfrom;
    LPSelect		pSelect;
    LPSend		pSend;
    LPSendto		pSendto;
    LPSethostent	pSethostent;
    LPSetnetent		pSetnetent;
    LPSetprotoent	pSetprotoent;
    LPSetservent	pSetservent;
    LPSetsockopt	pSetsockopt;
    LPShutdown		pShutdown;
    LPSocket		pSocket;
    LPSocketpair	pSocketpair;
#ifdef WIN32
    LPClosesocket	pClosesocket;
#endif
};

struct IPerlSockInfo
{
    unsigned long	nCount;	    /* number of entries expected */
    struct IPerlSock	perlSockList;
};

#define PerlSock_htonl(x)						\
	(*PL_piSock->pHtonl)(PL_piSock, x)
#define PerlSock_htons(x)						\
	(*PL_piSock->pHtons)(PL_piSock, x)
#define PerlSock_ntohl(x)						\
	(*PL_piSock->pNtohl)(PL_piSock, x)
#define PerlSock_ntohs(x)						\
	(*PL_piSock->pNtohs)(PL_piSock, x)
#define PerlSock_accept(s, a, l)					\
	(*PL_piSock->pAccept)(PL_piSock, s, a, l)
#define PerlSock_bind(s, n, l)						\
	(*PL_piSock->pBind)(PL_piSock, s, n, l)
#define PerlSock_connect(s, n, l)					\
	(*PL_piSock->pConnect)(PL_piSock, s, n, l)
#define PerlSock_endhostent()						\
	(*PL_piSock->pEndhostent)(PL_piSock)
#define PerlSock_endnetent()						\
	(*PL_piSock->pEndnetent)(PL_piSock)
#define PerlSock_endprotoent()						\
	(*PL_piSock->pEndprotoent)(PL_piSock)
#define PerlSock_endservent()						\
	(*PL_piSock->pEndservent)(PL_piSock)
#define PerlSock_gethostbyaddr(a, l, t)					\
	(*PL_piSock->pGethostbyaddr)(PL_piSock, a, l, t)
#define PerlSock_gethostbyname(n)					\
	(*PL_piSock->pGethostbyname)(PL_piSock, n)
#define PerlSock_gethostent()						\
	(*PL_piSock->pGethostent)(PL_piSock)
#define PerlSock_gethostname(n, l)					\
	(*PL_piSock->pGethostname)(PL_piSock, n, l)
#define PerlSock_getnetbyaddr(n, t)					\
	(*PL_piSock->pGetnetbyaddr)(PL_piSock, n, t)
#define PerlSock_getnetbyname(c)					\
	(*PL_piSock->pGetnetbyname)(PL_piSock, c)
#define PerlSock_getnetent()						\
	(*PL_piSock->pGetnetent)(PL_piSock)
#define PerlSock_getpeername(s, n, l)					\
	(*PL_piSock->pGetpeername)(PL_piSock, s, n, l)
#define PerlSock_getprotobyname(n)					\
	(*PL_piSock->pGetprotobyname)(PL_piSock, n)
#define PerlSock_getprotobynumber(n)					\
	(*PL_piSock->pGetprotobynumber)(PL_piSock, n)
#define PerlSock_getprotoent()						\
	(*PL_piSock->pGetprotoent)(PL_piSock)
#define PerlSock_getservbyname(n, p)					\
	(*PL_piSock->pGetservbyname)(PL_piSock, n, p)
#define PerlSock_getservbyport(port, p)					\
	(*PL_piSock->pGetservbyport)(PL_piSock, port, p)
#define PerlSock_getservent()						\
	(*PL_piSock->pGetservent)(PL_piSock)
#define PerlSock_getsockname(s, n, l)					\
	(*PL_piSock->pGetsockname)(PL_piSock, s, n, l)
#define PerlSock_getsockopt(s,l,n,v,i)					\
	(*PL_piSock->pGetsockopt)(PL_piSock, s, l, n, v, i)
#define PerlSock_inet_addr(c)						\
	(*PL_piSock->pInetAddr)(PL_piSock, c)
#define PerlSock_inet_ntoa(i)						\
	(*PL_piSock->pInetNtoa)(PL_piSock, i)
#define PerlSock_listen(s, b)						\
	(*PL_piSock->pListen)(PL_piSock, s, b)
#define PerlSock_recv(s, b, l, f)					\
	(*PL_piSock->pRecv)(PL_piSock, s, b, l, f)
#define PerlSock_recvfrom(s,b,l,f,from,fromlen)				\
	(*PL_piSock->pRecvfrom)(PL_piSock, s, b, l, f, from, fromlen)
#define PerlSock_select(n, r, w, e, t)					\
	(*PL_piSock->pSelect)(PL_piSock, n, (char*)r, (char*)w, (char*)e, t)
#define PerlSock_send(s, b, l, f)					\
	(*PL_piSock->pSend)(PL_piSock, s, b, l, f)
#define PerlSock_sendto(s, b, l, f, t, tlen)				\
	(*PL_piSock->pSendto)(PL_piSock, s, b, l, f, t, tlen)
#define PerlSock_sethostent(f)						\
	(*PL_piSock->pSethostent)(PL_piSock, f)
#define PerlSock_setnetent(f)						\
	(*PL_piSock->pSetnetent)(PL_piSock, f)
#define PerlSock_setprotoent(f)						\
	(*PL_piSock->pSetprotoent)(PL_piSock, f)
#define PerlSock_setservent(f)						\
	(*PL_piSock->pSetservent)(PL_piSock, f)
#define PerlSock_setsockopt(s, l, n, v, len)				\
	(*PL_piSock->pSetsockopt)(PL_piSock, s, l, n, v, len)
#define PerlSock_shutdown(s, h)						\
	(*PL_piSock->pShutdown)(PL_piSock, s, h)
#define PerlSock_socket(a, t, p)					\
	(*PL_piSock->pSocket)(PL_piSock, a, t, p)
#define PerlSock_socketpair(a, t, p, f)					\
	(*PL_piSock->pSocketpair)(PL_piSock, a, t, p, f)

#ifdef WIN32
#define	PerlSock_closesocket(s)						\
	(*PL_piSock->pClosesocket)(PL_piSock, s)
#endif

#else	/* PERL_OBJECT */

#define PerlSock_htonl(x)		htonl(x)
#define PerlSock_htons(x)		htons(x)
#define PerlSock_ntohl(x)		ntohl(x)
#define PerlSock_ntohs(x)		ntohs(x)
#define PerlSock_accept(s, a, l)	accept(s, a, l)
#define PerlSock_bind(s, n, l)		bind(s, n, l)
#define PerlSock_connect(s, n, l)	connect(s, n, l)

#define PerlSock_gethostbyaddr(a, l, t)	gethostbyaddr(a, l, t)
#define PerlSock_gethostbyname(n)	gethostbyname(n)
#define PerlSock_gethostent		gethostent
#define PerlSock_endhostent		endhostent
#define PerlSock_gethostname(n, l)	gethostname(n, l)

#define PerlSock_getnetbyaddr(n, t)	getnetbyaddr(n, t)
#define PerlSock_getnetbyname(n)	getnetbyname(n)
#define PerlSock_getnetent		getnetent
#define PerlSock_endnetent		endnetent
#define PerlSock_getpeername(s, n, l)	getpeername(s, n, l)

#define PerlSock_getprotobyname(n)	getprotobyname(n)
#define PerlSock_getprotobynumber(n)	getprotobynumber(n)
#define PerlSock_getprotoent		getprotoent
#define PerlSock_endprotoent		endprotoent

#define PerlSock_getservbyname(n, p)	getservbyname(n, p)
#define PerlSock_getservbyport(port, p)	getservbyport(port, p)
#define PerlSock_getservent		getservent
#define PerlSock_endservent		endservent

#define PerlSock_getsockname(s, n, l)	getsockname(s, n, l)
#define PerlSock_getsockopt(s,l,n,v,i)	getsockopt(s, l, n, v, i)
#define PerlSock_inet_addr(c)		inet_addr(c)
#define PerlSock_inet_ntoa(i)		inet_ntoa(i)
#define PerlSock_listen(s, b)		listen(s, b)
#define PerlSock_recv(s, b, l, f)	recv(s, b, l, f)
#define PerlSock_recvfrom(s, b, l, f, from, fromlen)			\
	recvfrom(s, b, l, f, from, fromlen)
#define PerlSock_select(n, r, w, e, t)	select(n, r, w, e, t)
#define PerlSock_send(s, b, l, f)	send(s, b, l, f)
#define PerlSock_sendto(s, b, l, f, t, tlen)				\
	sendto(s, b, l, f, t, tlen)
#define PerlSock_sethostent(f)		sethostent(f)
#define PerlSock_setnetent(f)		setnetent(f)
#define PerlSock_setprotoent(f)		setprotoent(f)
#define PerlSock_setservent(f)		setservent(f)
#define PerlSock_setsockopt(s, l, n, v, len)				\
	setsockopt(s, l, n, v, len)
#define PerlSock_shutdown(s, h)		shutdown(s, h)
#define PerlSock_socket(a, t, p)	socket(a, t, p)
#define PerlSock_socketpair(a, t, p, f)	socketpair(a, t, p, f)

#ifdef WIN32
#define PerlSock_closesocket(s)		closesocket(s)
#endif

#endif	/* PERL_OBJECT */

/* Mention

   HAS_READV
   HAS_RECVMSG
   HAS_SENDMSG
   HAS_WRITEV
   HAS_STRUCT_MSGHDR
   HAS_STRUCT_CMSGHDR

   here so that Configure picks them up.  Perl core does not
   use them but somebody might want to extend Socket:: or IO::
   someday.

   Jarkko Hietaniemi November 1998

   */

#endif	/* __Inc__IPerl___ */

