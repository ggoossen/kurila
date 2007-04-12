/* WIN32.C
 *
 * (c) 1995 Microsoft Corporation. All rights reserved. 
 * 		Developed by hip communications inc., http://info.hip.com/info/
 * Portions (c) 1993 Intergraph Corporation. All rights reserved.
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 */

#define WIN32_LEAN_AND_MEAN
#define WIN32IO_IS_STDIO
#include <tchar.h>
#ifdef __GNUC__
#define Win32_Winsock
#endif
#include <windows.h>

/* #include "config.h" */

#define PERLIO_NOT_STDIO 0 
#if !defined(PERLIO_IS_STDIO) && !defined(USE_SFIO)
#define PerlIO FILE
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include <fcntl.h>
#include <sys/stat.h>
#ifndef __GNUC__
/* assert.h conflicts with #define of assert in perl.h */
#include <assert.h>
#endif
#include <string.h>
#include <stdarg.h>
#include <float.h>
#include <time.h>
#if defined(_MSC_VER) || defined(__MINGW32__)
#include <sys/utime.h>
#else
#include <utime.h>
#endif

#ifdef __GNUC__
/* Mingw32 defaults to globing command line 
 * So we turn it off like this:
 */
int _CRT_glob = 0;
#endif

#define EXECF_EXEC 1
#define EXECF_SPAWN 2
#define EXECF_SPAWN_NOWAIT 3

static DWORD		os_id(void);
static void		get_shell(void);
static long		tokenize(char *str, char **dest, char ***destv);
static int		do_spawn2(char *cmd, int exectype);
static BOOL		has_redirection(char *ptr);
static long		filetime_to_clock(PFILETIME ft);
static BOOL		filetime_from_time(PFILETIME ft, time_t t);

char *	w32_perlshell_tokens = Nullch;
char **	w32_perlshell_vec;
long	w32_perlshell_items = -1;
DWORD	w32_platform = (DWORD)-1;
char	w32_perllib_root[MAX_PATH+1];
HANDLE	w32_perldll_handle = INVALID_HANDLE_VALUE;
#ifndef __BORLANDC__
long	w32_num_children = 0;
HANDLE	w32_child_pids[MAXIMUM_WAIT_OBJECTS];
#endif

#ifdef USE_THREADS
#  ifdef USE_DECLSPEC_THREAD
__declspec(thread) char	strerror_buffer[512];
__declspec(thread) char	getlogin_buffer[128];
#    ifdef HAVE_DES_FCRYPT
__declspec(thread) char	crypt_buffer[30];
#    endif
#  else
#    define strerror_buffer	(thr->i.Wstrerror_buffer)
#    define getlogin_buffer	(thr->i.Wgetlogin_buffer)
#    define crypt_buffer	(thr->i.Wcrypt_buffer)
#  endif
#else
char	strerror_buffer[512];
char	getlogin_buffer[128];
#  ifdef HAVE_DES_FCRYPT
char	crypt_buffer[30];
#  endif
#endif

int 
IsWin95(void) {
    return (os_id() == VER_PLATFORM_WIN32_WINDOWS);
}

int
IsWinNT(void) {
    return (os_id() == VER_PLATFORM_WIN32_NT);
}

char *
win32_perllib_path(char *sfx,...)
{
    va_list ap;
    char *end;
    va_start(ap,sfx);
    GetModuleFileName((w32_perldll_handle == INVALID_HANDLE_VALUE) 
		      ? GetModuleHandle(NULL)
		      : w32_perldll_handle,
		      w32_perllib_root, 
		      sizeof(w32_perllib_root));
    *(end = strrchr(w32_perllib_root, '\\')) = '\0';
    if (stricmp(end-4,"\\bin") == 0)
     end -= 4;
    strcpy(end,"\\lib");
    while (sfx)
     {
      strcat(end,"\\");
      strcat(end,sfx);
      sfx = va_arg(ap,char *);
     }
    va_end(ap); 
    return (w32_perllib_root);
}


static BOOL
has_redirection(char *ptr)
{
    int inquote = 0;
    char quote = '\0';

    /*
     * Scan string looking for redirection (< or >) or pipe
     * characters (|) that are not in a quoted string
     */
    while(*ptr) {
	switch(*ptr) {
	case '\'':
	case '\"':
	    if(inquote) {
		if(quote == *ptr) {
		    inquote = 0;
		    quote = '\0';
		}
	    }
	    else {
		quote = *ptr;
		inquote++;
	    }
	    break;
	case '>':
	case '<':
	case '|':
	    if(!inquote)
		return TRUE;
	default:
	    break;
	}
	++ptr;
    }
    return FALSE;
}

/* since the current process environment is being updated in util.c
 * the library functions will get the correct environment
 */
PerlIO *
my_popen(char *cmd, char *mode)
{
#ifdef FIXCMD
#define fixcmd(x)	{					\
			    char *pspace = strchr((x),' ');	\
			    if (pspace) {			\
				char *p = (x);			\
				while (p < pspace) {		\
				    if (*p == '/')		\
					*p = '\\';		\
				    p++;			\
				}				\
			    }					\
			}
#else
#define fixcmd(x)
#endif
    fixcmd(cmd);
#ifdef __BORLANDC__ /* workaround a Borland stdio bug */
    win32_fflush(stdout);
    win32_fflush(stderr);
#endif
    return win32_popen(cmd, mode);
}

long
my_pclose(PerlIO *fp)
{
    return win32_pclose(fp);
}

static DWORD
os_id(void)
{
    static OSVERSIONINFO osver;

    if (osver.dwPlatformId != w32_platform) {
	memset(&osver, 0, sizeof(OSVERSIONINFO));
	osver.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
	GetVersionEx(&osver);
	w32_platform = osver.dwPlatformId;
    }
    return (w32_platform);
}

/* Tokenize a string.  Words are null-separated, and the list
 * ends with a doubled null.  Any character (except null and
 * including backslash) may be escaped by preceding it with a
 * backslash (the backslash will be stripped).
 * Returns number of words in result buffer.
 */
static long
tokenize(char *str, char **dest, char ***destv)
{
    char *retstart = Nullch;
    char **retvstart = 0;
    int items = -1;
    if (str) {
	int slen = strlen(str);
	register char *ret;
	register char **retv;
	New(1307, ret, slen+2, char);
	New(1308, retv, (slen+3)/2, char*);

	retstart = ret;
	retvstart = retv;
	*retv = ret;
	items = 0;
	while (*str) {
	    *ret = *str++;
	    if (*ret == '\\' && *str)
		*ret = *str++;
	    else if (*ret == ' ') {
		while (*str == ' ')
		    str++;
		if (ret == retstart)
		    ret--;
		else {
		    *ret = '\0';
		    ++items;
		    if (*str)
			*++retv = ret+1;
		}
	    }
	    else if (!*str)
		++items;
	    ret++;
	}
	retvstart[items] = Nullch;
	*ret++ = '\0';
	*ret = '\0';
    }
    *dest = retstart;
    *destv = retvstart;
    return items;
}

static void
get_shell(void)
{
    if (!w32_perlshell_tokens) {
	/* we don't use COMSPEC here for two reasons:
	 *  1. the same reason perl on UNIX doesn't use SHELL--rampant and
	 *     uncontrolled unportability of the ensuing scripts.
	 *  2. PERL5SHELL could be set to a shell that may not be fit for
	 *     interactive use (which is what most programs look in COMSPEC
	 *     for).
	 */
	char* defaultshell = (IsWinNT() ? "cmd.exe /x/c" : "command.com /c");
	char *usershell = getenv("PERL5SHELL");
	w32_perlshell_items = tokenize(usershell ? usershell : defaultshell,
				       &w32_perlshell_tokens,
				       &w32_perlshell_vec);
    }
}

int
do_aspawn(void *vreally, void **vmark, void **vsp)
{
    SV *really = (SV*)vreally;
    SV **mark = (SV**)vmark;
    SV **sp = (SV**)vsp;
    char **argv;
    char *str;
    int status;
    int flag = P_WAIT;
    int index = 0;

    if (sp <= mark)
	return -1;

    get_shell();
    New(1306, argv, (sp - mark) + w32_perlshell_items + 2, char*);

    if (SvNIOKp(*(mark+1)) && !SvPOKp(*(mark+1))) {
	++mark;
	flag = SvIVx(*mark);
    }

    while(++mark <= sp) {
	if (*mark && (str = SvPV(*mark, na)))
	    argv[index++] = str;
	else
	    argv[index++] = "";
    }
    argv[index++] = 0;
   
    status = win32_spawnvp(flag,
			   (really ? SvPV(really,na) : argv[0]),
			   (const char* const*)argv);

    if (status < 0 && errno == ENOEXEC) {
	/* possible shell-builtin, invoke with shell */
	int sh_items;
	sh_items = w32_perlshell_items;
	while (--index >= 0)
	    argv[index+sh_items] = argv[index];
	while (--sh_items >= 0)
	    argv[sh_items] = w32_perlshell_vec[sh_items];
   
	status = win32_spawnvp(flag,
			       (really ? SvPV(really,na) : argv[0]),
			       (const char* const*)argv);
    }

    if (status < 0) {
	if (dowarn)
	    warn("Can't spawn \"%s\": %s", argv[0], strerror(errno));
	status = 255 * 256;
    }
    else if (flag != P_NOWAIT)
	status *= 256;
    Safefree(argv);
    return (statusvalue = status);
}

static int
do_spawn2(char *cmd, int exectype)
{
    char **a;
    char *s;
    char **argv;
    int status = -1;
    BOOL needToTry = TRUE;
    char *cmd2;

    /* Save an extra exec if possible. See if there are shell
     * metacharacters in it */
    if(!has_redirection(cmd)) {
	New(1301,argv, strlen(cmd) / 2 + 2, char*);
	New(1302,cmd2, strlen(cmd) + 1, char);
	strcpy(cmd2, cmd);
	a = argv;
	for (s = cmd2; *s;) {
	    while (*s && isspace(*s))
		s++;
	    if (*s)
		*(a++) = s;
	    while(*s && !isspace(*s))
		s++;
	    if(*s)
		*s++ = '\0';
	}
	*a = Nullch;
	if (argv[0]) {
	    switch (exectype) {
	    case EXECF_SPAWN:
		status = win32_spawnvp(P_WAIT, argv[0],
				       (const char* const*)argv);
		break;
	    case EXECF_SPAWN_NOWAIT:
		status = win32_spawnvp(P_NOWAIT, argv[0],
				       (const char* const*)argv);
		break;
	    case EXECF_EXEC:
		status = win32_execvp(argv[0], (const char* const*)argv);
		break;
	    }
	    if (status != -1 || errno == 0)
		needToTry = FALSE;
	}
	Safefree(argv);
	Safefree(cmd2);
    }
    if (needToTry) {
	char **argv;
	int i = -1;
	get_shell();
	New(1306, argv, w32_perlshell_items + 2, char*);
	while (++i < w32_perlshell_items)
	    argv[i] = w32_perlshell_vec[i];
	argv[i++] = cmd;
	argv[i] = Nullch;
	switch (exectype) {
	case EXECF_SPAWN:
	    status = win32_spawnvp(P_WAIT, argv[0],
				   (const char* const*)argv);
	    break;
	case EXECF_SPAWN_NOWAIT:
	    status = win32_spawnvp(P_NOWAIT, argv[0],
				   (const char* const*)argv);
	    break;
	case EXECF_EXEC:
	    status = win32_execvp(argv[0], (const char* const*)argv);
	    break;
	}
	cmd = argv[0];
	Safefree(argv);
    }
    if (status < 0) {
	if (dowarn)
	    warn("Can't %s \"%s\": %s",
		 (exectype == EXECF_EXEC ? "exec" : "spawn"),
		 cmd, strerror(errno));
	status = 255 * 256;
    }
    else if (exectype != EXECF_SPAWN_NOWAIT)
	status *= 256;
    return (statusvalue = status);
}

int
do_spawn(char *cmd)
{
    return do_spawn2(cmd, EXECF_SPAWN);
}

int
do_spawn_nowait(char *cmd)
{
    return do_spawn2(cmd, EXECF_SPAWN_NOWAIT);
}

bool
do_exec(char *cmd)
{
    do_spawn2(cmd, EXECF_EXEC);
    return FALSE;
}


#define PATHLEN 1024

/* The idea here is to read all the directory names into a string table
 * (separated by nulls) and when one of the other dir functions is called
 * return the pointer to the current file name.
 */
DIR *
opendir(char *filename)
{
    DIR            *p;
    long            len;
    long            idx;
    char            scannamespc[PATHLEN];
    char       *scanname = scannamespc;
    struct stat     sbuf;
    WIN32_FIND_DATA FindData;
    HANDLE          fh;
/*  char            root[_MAX_PATH];*/
/*  char            volname[_MAX_PATH];*/
/*  DWORD           serial, maxname, flags;*/
/*  BOOL            downcase;*/
/*  char           *dummy;*/

    /* check to see if filename is a directory */
    if (win32_stat(filename, &sbuf) < 0 || (sbuf.st_mode & S_IFDIR) == 0) {
	/* CRT is buggy on sharenames, so make sure it really isn't */
	DWORD r = GetFileAttributes(filename);
	if (r == 0xffffffff || !(r & FILE_ATTRIBUTE_DIRECTORY))
	    return NULL;
    }

    /* get the file system characteristics */
/*  if(GetFullPathName(filename, MAX_PATH, root, &dummy)) {
 *	if(dummy = strchr(root, '\\'))
 *	    *++dummy = '\0';
 *	if(GetVolumeInformation(root, volname, MAX_PATH, &serial,
 *				&maxname, &flags, 0, 0)) {
 *	    downcase = !(flags & FS_CASE_IS_PRESERVED);
 *	}
 *  }
 *  else {
 *	downcase = TRUE;
 *  }
 */
    /* Get us a DIR structure */
    Newz(1303, p, 1, DIR);
    if(p == NULL)
	return NULL;

    /* Create the search pattern */
    strcpy(scanname, filename);

    if(index("/\\", *(scanname + strlen(scanname) - 1)) == NULL)
	strcat(scanname, "/*");
    else
	strcat(scanname, "*");

    /* do the FindFirstFile call */
    fh = FindFirstFile(scanname, &FindData);
    if(fh == INVALID_HANDLE_VALUE) {
	return NULL;
    }

    /* now allocate the first part of the string table for
     * the filenames that we find.
     */
    idx = strlen(FindData.cFileName)+1;
    New(1304, p->start, idx, char);
    if(p->start == NULL) {
	croak("opendir: malloc failed!\n");
    }
    strcpy(p->start, FindData.cFileName);
/*  if(downcase)
 *	strlwr(p->start);
 */
    p->nfiles++;

    /* loop finding all the files that match the wildcard
     * (which should be all of them in this directory!).
     * the variable idx should point one past the null terminator
     * of the previous string found.
     */
    while (FindNextFile(fh, &FindData)) {
	len = strlen(FindData.cFileName);
	/* bump the string table size by enough for the
	 * new name and it's null terminator
	 */
	Renew(p->start, idx+len+1, char);
	if(p->start == NULL) {
	    croak("opendir: malloc failed!\n");
	}
	strcpy(&p->start[idx], FindData.cFileName);
/*	if (downcase) 
 *	    strlwr(&p->start[idx]);
 */
		p->nfiles++;
		idx += len+1;
	}
	FindClose(fh);
	p->size = idx;
	p->curr = p->start;
	return p;
}


/* Readdir just returns the current string pointer and bumps the
 * string pointer to the nDllExport entry.
 */
struct direct *
readdir(DIR *dirp)
{
    int         len;
    static int  dummy = 0;

    if (dirp->curr) {
	/* first set up the structure to return */
	len = strlen(dirp->curr);
	strcpy(dirp->dirstr.d_name, dirp->curr);
	dirp->dirstr.d_namlen = len;

	/* Fake an inode */
	dirp->dirstr.d_ino = dummy++;

	/* Now set up for the nDllExport call to readdir */
	dirp->curr += len + 1;
	if (dirp->curr >= (dirp->start + dirp->size)) {
	    dirp->curr = NULL;
	}

	return &(dirp->dirstr);
    } 
    else
	return NULL;
}

/* Telldir returns the current string pointer position */
long
telldir(DIR *dirp)
{
    return (long) dirp->curr;
}


/* Seekdir moves the string pointer to a previously saved position
 *(Saved by telldir).
 */
void
seekdir(DIR *dirp, long loc)
{
    dirp->curr = (char *)loc;
}

/* Rewinddir resets the string pointer to the start */
void
rewinddir(DIR *dirp)
{
    dirp->curr = dirp->start;
}

/* free the memory allocated by opendir */
int
closedir(DIR *dirp)
{
    Safefree(dirp->start);
    Safefree(dirp);
    return 1;
}


/*
 * various stubs
 */


/* Ownership
 *
 * Just pretend that everyone is a superuser. NT will let us know if
 * we don\'t really have permission to do something.
 */

#define ROOT_UID    ((uid_t)0)
#define ROOT_GID    ((gid_t)0)

uid_t
getuid(void)
{
    return ROOT_UID;
}

uid_t
geteuid(void)
{
    return ROOT_UID;
}

gid_t
getgid(void)
{
    return ROOT_GID;
}

gid_t
getegid(void)
{
    return ROOT_GID;
}

int
setuid(uid_t auid)
{ 
    return (auid == ROOT_UID ? 0 : -1);
}

int
setgid(gid_t agid)
{
    return (agid == ROOT_GID ? 0 : -1);
}

char *
getlogin(void)
{
    dTHR;
    char *buf = getlogin_buffer;
    DWORD size = sizeof(getlogin_buffer);
    if (GetUserName(buf,&size))
	return buf;
    return (char*)NULL;
}

/*
 * pretended kill
 */
int
kill(int pid, int sig)
{
    HANDLE hProcess= OpenProcess(PROCESS_ALL_ACCESS, TRUE, pid);

    if (hProcess == NULL) {
	croak("kill process failed!\n");
    }
    else {
	if (!TerminateProcess(hProcess, sig))
	    croak("kill process failed!\n");
	CloseHandle(hProcess);
    }
    return 0;
}
      
/*
 * File system stuff
 */

DllExport unsigned int
win32_sleep(unsigned int t)
{
    Sleep(t*1000);
    return 0;
}

DllExport int
win32_stat(const char *path, struct stat *buffer)
{
    char		t[MAX_PATH]; 
    const char	*p = path;
    int		l = strlen(path);
    int		res;

    if (l > 1) {
	switch(path[l - 1]) {
	case '\\':
	case '/':
	    if (path[l - 2] != ':') {
		strncpy(t, path, l - 1);
		t[l - 1] = 0;
		p = t;
	    };
	}
    }
    res = stat(p,buffer);
#ifdef __BORLANDC__
    if (res == 0) {
	if (S_ISDIR(buffer->st_mode))
	    buffer->st_mode |= S_IWRITE | S_IEXEC;
	else if (S_ISREG(buffer->st_mode)) {
	    if (l >= 4 && path[l-4] == '.') {
		const char *e = path + l - 3;
		if (strnicmp(e,"exe",3)
		    && strnicmp(e,"bat",3)
		    && strnicmp(e,"com",3)
		    && (IsWin95() || strnicmp(e,"cmd",3)))
		    buffer->st_mode &= ~S_IEXEC;
		else
		    buffer->st_mode |= S_IEXEC;
	    }
	    else
		buffer->st_mode &= ~S_IEXEC;
	}
    }
#endif
    return res;
}

#ifndef USE_WIN32_RTL_ENV

DllExport char *
win32_getenv(const char *name)
{
    static char *curitem = Nullch;
    static DWORD curlen = 512;
    DWORD needlen;
    if (!curitem)
	New(1305,curitem,curlen,char);
    if (!(needlen = GetEnvironmentVariable(name,curitem,curlen)))
	return Nullch;
    while (needlen > curlen) {
	Renew(curitem,needlen,char);
	curlen = needlen;
	needlen = GetEnvironmentVariable(name,curitem,curlen);
    }
    return curitem;
}

#endif

static long
filetime_to_clock(PFILETIME ft)
{
 __int64 qw = ft->dwHighDateTime;
 qw <<= 32;
 qw |= ft->dwLowDateTime;
 qw /= 10000;  /* File time ticks at 0.1uS, clock at 1mS */
 return (long) qw;
}

DllExport int
win32_times(struct tms *timebuf)
{
    FILETIME user;
    FILETIME kernel;
    FILETIME dummy;
    if (GetProcessTimes(GetCurrentProcess(), &dummy, &dummy, 
                        &kernel,&user)) {
	timebuf->tms_utime = filetime_to_clock(&user);
	timebuf->tms_stime = filetime_to_clock(&kernel);
	timebuf->tms_cutime = 0;
	timebuf->tms_cstime = 0;
        
    } else { 
        /* That failed - e.g. Win95 fallback to clock() */
        clock_t t = clock();
	timebuf->tms_utime = t;
	timebuf->tms_stime = 0;
	timebuf->tms_cutime = 0;
	timebuf->tms_cstime = 0;
    }
    return 0;
}

/* fix utime() so it works on directories in NT
 * thanks to Jan Dubois <jan.dubois@ibm.net>
 */
static BOOL
filetime_from_time(PFILETIME pFileTime, time_t Time)
{
    struct tm *pTM = gmtime(&Time);
    SYSTEMTIME SystemTime;

    if (pTM == NULL)
	return FALSE;

    SystemTime.wYear   = pTM->tm_year + 1900;
    SystemTime.wMonth  = pTM->tm_mon + 1;
    SystemTime.wDay    = pTM->tm_mday;
    SystemTime.wHour   = pTM->tm_hour;
    SystemTime.wMinute = pTM->tm_min;
    SystemTime.wSecond = pTM->tm_sec;
    SystemTime.wMilliseconds = 0;

    return SystemTimeToFileTime(&SystemTime, pFileTime);
}

DllExport int
win32_utime(const char *filename, struct utimbuf *times)
{
    HANDLE handle;
    FILETIME ftCreate;
    FILETIME ftAccess;
    FILETIME ftWrite;
    struct utimbuf TimeBuffer;

    int rc = utime(filename,times);
    /* EACCES: path specifies directory or readonly file */
    if (rc == 0 || errno != EACCES /* || !IsWinNT() */)
	return rc;

    if (times == NULL) {
	times = &TimeBuffer;
	time(&times->actime);
	times->modtime = times->actime;
    }

    /* This will (and should) still fail on readonly files */
    handle = CreateFile(filename, GENERIC_READ | GENERIC_WRITE,
			FILE_SHARE_READ | FILE_SHARE_DELETE, NULL,
			OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, NULL);
    if (handle == INVALID_HANDLE_VALUE)
	return rc;

    if (GetFileTime(handle, &ftCreate, &ftAccess, &ftWrite) &&
	filetime_from_time(&ftAccess, times->actime) &&
	filetime_from_time(&ftWrite, times->modtime) &&
	SetFileTime(handle, &ftCreate, &ftAccess, &ftWrite))
    {
	rc = 0;
    }

    CloseHandle(handle);
    return rc;
}

DllExport int
win32_wait(int *status)
{
#ifdef __BORLANDC__
    return wait(status);
#else
    /* XXX this wait emulation only knows about processes
     * spawned via win32_spawnvp(P_NOWAIT, ...).
     */
    int i, retval;
    DWORD exitcode, waitcode;

    if (!w32_num_children) {
	errno = ECHILD;
	return -1;
    }

    /* if a child exists, wait for it to die */
    waitcode = WaitForMultipleObjects(w32_num_children,
				      w32_child_pids,
				      FALSE,
				      INFINITE);
    if (waitcode != WAIT_FAILED) {
	if (waitcode >= WAIT_ABANDONED_0
	    && waitcode < WAIT_ABANDONED_0 + w32_num_children)
	    i = waitcode - WAIT_ABANDONED_0;
	else
	    i = waitcode - WAIT_OBJECT_0;
	if (GetExitCodeProcess(w32_child_pids[i], &exitcode) ) {
	    CloseHandle(w32_child_pids[i]);
	    *status = (int)((exitcode & 0xff) << 8);
	    retval = (int)w32_child_pids[i];
	    Copy(&w32_child_pids[i+1], &w32_child_pids[i],
		 (w32_num_children-i-1), HANDLE);
	    w32_num_children--;
	    return retval;
	}
    }

FAILED:
    errno = GetLastError();
    return -1;

#endif
}

static UINT timerid = 0;

static VOID CALLBACK TimerProc(HWND win, UINT msg, UINT id, DWORD time)
{
 KillTimer(NULL,timerid);
 timerid=0;  
 sighandler(14);
}

DllExport unsigned int
win32_alarm(unsigned int sec)
{
    /* 
     * the 'obvious' implentation is SetTimer() with a callback
     * which does whatever receiving SIGALRM would do 
     * we cannot use SIGALRM even via raise() as it is not 
     * one of the supported codes in <signal.h>
     *
     * Snag is unless something is looking at the message queue
     * nothing happens :-(
     */ 
    if (sec)
     {
      timerid = SetTimer(NULL,timerid,sec*1000,(TIMERPROC)TimerProc);
      if (!timerid)
       croak("Cannot set timer");
     } 
    else
     {
      if (timerid)
       {
        KillTimer(NULL,timerid);
        timerid=0;  
       }
     }
    return 0;
}

#ifdef HAVE_DES_FCRYPT
extern char *	des_fcrypt(char *cbuf, const char *txt, const char *salt);

DllExport char *
win32_crypt(const char *txt, const char *salt)
{
    dTHR;
    return des_fcrypt(crypt_buffer, txt, salt);
}
#endif

#ifdef USE_FIXED_OSFHANDLE

EXTERN_C int __cdecl _alloc_osfhnd(void);
EXTERN_C int __cdecl _set_osfhnd(int fh, long value);
EXTERN_C void __cdecl _lock_fhandle(int);
EXTERN_C void __cdecl _unlock_fhandle(int);
EXTERN_C void __cdecl _unlock(int);

#if	(_MSC_VER >= 1000)
typedef struct	{
    long osfhnd;    /* underlying OS file HANDLE */
    char osfile;    /* attributes of file (e.g., open in text mode?) */
    char pipech;    /* one char buffer for handles opened on pipes */
#if defined (_MT) && !defined (DLL_FOR_WIN32S)
    int lockinitflag;
    CRITICAL_SECTION lock;
#endif  /* defined (_MT) && !defined (DLL_FOR_WIN32S) */
}	ioinfo;

EXTERN_C ioinfo * __pioinfo[];

#define IOINFO_L2E			5
#define IOINFO_ARRAY_ELTS	(1 << IOINFO_L2E)
#define _pioinfo(i)	(__pioinfo[i >> IOINFO_L2E] + (i & (IOINFO_ARRAY_ELTS - 1)))
#define _osfile(i)	(_pioinfo(i)->osfile)

#else	/* (_MSC_VER >= 1000) */
extern char _osfile[];
#endif	/* (_MSC_VER >= 1000) */

#define FOPEN			0x01	/* file handle open */
#define FAPPEND			0x20	/* file handle opened O_APPEND */
#define FDEV			0x40	/* file handle refers to device */
#define FTEXT			0x80	/* file handle is in text mode */

#define _STREAM_LOCKS   26		/* Table of stream locks */
#define _LAST_STREAM_LOCK  (_STREAM_LOCKS+_NSTREAM_-1)	/* Last stream lock */
#define _FH_LOCKS          (_LAST_STREAM_LOCK+1)	/* Table of fh locks */

/***
*int my_open_osfhandle(long osfhandle, int flags) - open C Runtime file handle
*
*Purpose:
*       This function allocates a free C Runtime file handle and associates
*       it with the Win32 HANDLE specified by the first parameter. This is a
*		temperary fix for WIN95's brain damage GetFileType() error on socket
*		we just bypass that call for socket
*
*Entry:
*       long osfhandle - Win32 HANDLE to associate with C Runtime file handle.
*       int flags      - flags to associate with C Runtime file handle.
*
*Exit:
*       returns index of entry in fh, if successful
*       return -1, if no free entry is found
*
*Exceptions:
*
*******************************************************************************/

static int
my_open_osfhandle(long osfhandle, int flags)
{
    int fh;
    char fileflags;		/* _osfile flags */

    /* copy relevant flags from second parameter */
    fileflags = FDEV;

    if(flags & O_APPEND)
	fileflags |= FAPPEND;

    if(flags & O_TEXT)
	fileflags |= FTEXT;

    /* attempt to allocate a C Runtime file handle */
    if((fh = _alloc_osfhnd()) == -1) {
	errno = EMFILE;		/* too many open files */
	_doserrno = 0L;		/* not an OS error */
	return -1;		/* return error to caller */
    }

    /* the file is open. now, set the info in _osfhnd array */
    _set_osfhnd(fh, osfhandle);

    fileflags |= FOPEN;		/* mark as open */

#if (_MSC_VER >= 1000)
    _osfile(fh) = fileflags;	/* set osfile entry */
    _unlock_fhandle(fh);
#else
    _osfile[fh] = fileflags;	/* set osfile entry */
    _unlock(fh+_FH_LOCKS);		/* unlock handle */
#endif

    return fh;			/* return handle */
}

#define _open_osfhandle my_open_osfhandle
#endif	/* USE_FIXED_OSFHANDLE */

/* simulate flock by locking a range on the file */

#define LK_ERR(f,i)	((f) ? (i = 0) : (errno = GetLastError()))
#define LK_LEN		0xffff0000

DllExport int
win32_flock(int fd, int oper)
{
    OVERLAPPED o;
    int i = -1;
    HANDLE fh;

    if (!IsWinNT()) {
	croak("flock() unimplemented on this platform");
	return -1;
    }
    fh = (HANDLE)_get_osfhandle(fd);
    memset(&o, 0, sizeof(o));

    switch(oper) {
    case LOCK_SH:		/* shared lock */
	LK_ERR(LockFileEx(fh, 0, 0, LK_LEN, 0, &o),i);
	break;
    case LOCK_EX:		/* exclusive lock */
	LK_ERR(LockFileEx(fh, LOCKFILE_EXCLUSIVE_LOCK, 0, LK_LEN, 0, &o),i);
	break;
    case LOCK_SH|LOCK_NB:	/* non-blocking shared lock */
	LK_ERR(LockFileEx(fh, LOCKFILE_FAIL_IMMEDIATELY, 0, LK_LEN, 0, &o),i);
	break;
    case LOCK_EX|LOCK_NB:	/* non-blocking exclusive lock */
	LK_ERR(LockFileEx(fh,
		       LOCKFILE_EXCLUSIVE_LOCK|LOCKFILE_FAIL_IMMEDIATELY,
		       0, LK_LEN, 0, &o),i);
	break;
    case LOCK_UN:		/* unlock lock */
	LK_ERR(UnlockFileEx(fh, 0, LK_LEN, 0, &o),i);
	break;
    default:			/* unknown */
	errno = EINVAL;
	break;
    }
    return i;
}

#undef LK_ERR
#undef LK_LEN

/*
 *  redirected io subsystem for all XS modules
 *
 */

DllExport int *
win32_errno(void)
{
    return (&errno);
}

DllExport char ***
win32_environ(void)
{
    return (&(_environ));
}

/* the rest are the remapped stdio routines */
DllExport FILE *
win32_stderr(void)
{
    return (stderr);
}

DllExport FILE *
win32_stdin(void)
{
    return (stdin);
}

DllExport FILE *
win32_stdout()
{
    return (stdout);
}

DllExport int
win32_ferror(FILE *fp)
{
    return (ferror(fp));
}


DllExport int
win32_feof(FILE *fp)
{
    return (feof(fp));
}

/*
 * Since the errors returned by the socket error function 
 * WSAGetLastError() are not known by the library routine strerror
 * we have to roll our own.
 */

DllExport char *
win32_strerror(int e) 
{
#ifndef __BORLANDC__		/* Borland intolerance */
    extern int sys_nerr;
#endif
    DWORD source = 0;

    if(e < 0 || e > sys_nerr) {
        dTHR;
	if(e < 0)
	    e = GetLastError();

	if(FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM, &source, e, 0,
			 strerror_buffer, sizeof(strerror_buffer), NULL) == 0) 
	    strcpy(strerror_buffer, "Unknown Error");

	return strerror_buffer;
    }
    return strerror(e);
}

DllExport void
win32_str_os_error(void *sv, DWORD dwErr)
{
    DWORD dwLen;
    char *sMsg;
    dwLen = FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER
			  |FORMAT_MESSAGE_IGNORE_INSERTS
			  |FORMAT_MESSAGE_FROM_SYSTEM, NULL,
			   dwErr, 0, (char *)&sMsg, 1, NULL);
    if (0 < dwLen) {
	while (0 < dwLen  &&  isspace(sMsg[--dwLen]))
	    ;
	if ('.' != sMsg[dwLen])
	    dwLen++;
	sMsg[dwLen]= '\0';
    }
    if (0 == dwLen) {
	sMsg = LocalAlloc(0, 64/**sizeof(TCHAR)*/);
	dwLen = sprintf(sMsg,
			"Unknown error #0x%lX (lookup 0x%lX)",
			dwErr, GetLastError());
    }
    sv_setpvn((SV*)sv, sMsg, dwLen);
    LocalFree(sMsg);
}


DllExport int
win32_fprintf(FILE *fp, const char *format, ...)
{
    va_list marker;
    va_start(marker, format);     /* Initialize variable arguments. */

    return (vfprintf(fp, format, marker));
}

DllExport int
win32_printf(const char *format, ...)
{
    va_list marker;
    va_start(marker, format);     /* Initialize variable arguments. */

    return (vprintf(format, marker));
}

DllExport int
win32_vfprintf(FILE *fp, const char *format, va_list args)
{
    return (vfprintf(fp, format, args));
}

DllExport int
win32_vprintf(const char *format, va_list args)
{
    return (vprintf(format, args));
}

DllExport size_t
win32_fread(void *buf, size_t size, size_t count, FILE *fp)
{
    return fread(buf, size, count, fp);
}

DllExport size_t
win32_fwrite(const void *buf, size_t size, size_t count, FILE *fp)
{
    return fwrite(buf, size, count, fp);
}

DllExport FILE *
win32_fopen(const char *filename, const char *mode)
{
    if (stricmp(filename, "/dev/null")==0)
	return fopen("NUL", mode);
    return fopen(filename, mode);
}

#ifndef USE_SOCKETS_AS_HANDLES
#undef fdopen
#define fdopen my_fdopen
#endif

DllExport FILE *
win32_fdopen( int handle, const char *mode)
{
    return fdopen(handle, (char *) mode);
}

DllExport FILE *
win32_freopen( const char *path, const char *mode, FILE *stream)
{
    if (stricmp(path, "/dev/null")==0)
	return freopen("NUL", mode, stream);
    return freopen(path, mode, stream);
}

DllExport int
win32_fclose(FILE *pf)
{
    return my_fclose(pf);	/* defined in win32sck.c */
}

DllExport int
win32_fputs(const char *s,FILE *pf)
{
    return fputs(s, pf);
}

DllExport int
win32_fputc(int c,FILE *pf)
{
    return fputc(c,pf);
}

DllExport int
win32_ungetc(int c,FILE *pf)
{
    return ungetc(c,pf);
}

DllExport int
win32_getc(FILE *pf)
{
    return getc(pf);
}

DllExport int
win32_fileno(FILE *pf)
{
    return fileno(pf);
}

DllExport void
win32_clearerr(FILE *pf)
{
    clearerr(pf);
    return;
}

DllExport int
win32_fflush(FILE *pf)
{
    return fflush(pf);
}

DllExport long
win32_ftell(FILE *pf)
{
    return ftell(pf);
}

DllExport int
win32_fseek(FILE *pf,long offset,int origin)
{
    return fseek(pf, offset, origin);
}

DllExport int
win32_fgetpos(FILE *pf,fpos_t *p)
{
    return fgetpos(pf, p);
}

DllExport int
win32_fsetpos(FILE *pf,const fpos_t *p)
{
    return fsetpos(pf, p);
}

DllExport void
win32_rewind(FILE *pf)
{
    rewind(pf);
    return;
}

DllExport FILE*
win32_tmpfile(void)
{
    return tmpfile();
}

DllExport void
win32_abort(void)
{
    abort();
    return;
}

DllExport int
win32_fstat(int fd,struct stat *sbufptr)
{
    return fstat(fd,sbufptr);
}

DllExport int
win32_pipe(int *pfd, unsigned int size, int mode)
{
    return _pipe(pfd, size, mode);
}

DllExport FILE*
win32_popen(const char *command, const char *mode)
{
    return _popen(command, mode);
}

DllExport int
win32_pclose(FILE *pf)
{
    return _pclose(pf);
}

DllExport int
win32_setmode(int fd, int mode)
{
    return setmode(fd, mode);
}

DllExport long
win32_lseek(int fd, long offset, int origin)
{
    return lseek(fd, offset, origin);
}

DllExport long
win32_tell(int fd)
{
    return tell(fd);
}

DllExport int
win32_open(const char *path, int flag, ...)
{
    va_list ap;
    int pmode;

    va_start(ap, flag);
    pmode = va_arg(ap, int);
    va_end(ap);

    if (stricmp(path, "/dev/null")==0)
	return open("NUL", flag, pmode);
    return open(path,flag,pmode);
}

DllExport int
win32_close(int fd)
{
    return close(fd);
}

DllExport int
win32_eof(int fd)
{
    return eof(fd);
}

DllExport int
win32_dup(int fd)
{
    return dup(fd);
}

DllExport int
win32_dup2(int fd1,int fd2)
{
    return dup2(fd1,fd2);
}

DllExport int
win32_read(int fd, void *buf, unsigned int cnt)
{
    return read(fd, buf, cnt);
}

DllExport int
win32_write(int fd, const void *buf, unsigned int cnt)
{
    return write(fd, buf, cnt);
}

DllExport int
win32_mkdir(const char *dir, int mode)
{
    return mkdir(dir); /* just ignore mode */
}

DllExport int
win32_rmdir(const char *dir)
{
    return rmdir(dir);
}

DllExport int
win32_chdir(const char *dir)
{
    return chdir(dir);
}

DllExport int
win32_spawnvp(int mode, const char *cmdname, const char *const *argv)
{
    int status;

    status = spawnvp(mode, cmdname, (char * const *) argv);
#ifndef __BORLANDC__
    /* XXX For the P_NOWAIT case, Borland RTL returns pinfo.dwProcessId
     * while VC RTL returns pinfo.hProcess. For purposes of the custom
     * implementation of win32_wait(), we assume the latter.
     */
    if (mode == P_NOWAIT && status >= 0)
	w32_child_pids[w32_num_children++] = (HANDLE)status;
#endif
    return status;
}

DllExport int
win32_execvp(const char *cmdname, const char *const *argv)
{
    return execvp(cmdname, (char *const *)argv);
}

DllExport void
win32_perror(const char *str)
{
    perror(str);
}

DllExport void
win32_setbuf(FILE *pf, char *buf)
{
    setbuf(pf, buf);
}

DllExport int
win32_setvbuf(FILE *pf, char *buf, int type, size_t size)
{
    return setvbuf(pf, buf, type, size);
}

DllExport int
win32_flushall(void)
{
    return flushall();
}

DllExport int
win32_fcloseall(void)
{
    return fcloseall();
}

DllExport char*
win32_fgets(char *s, int n, FILE *pf)
{
    return fgets(s, n, pf);
}

DllExport char*
win32_gets(char *s)
{
    return gets(s);
}

DllExport int
win32_fgetc(FILE *pf)
{
    return fgetc(pf);
}

DllExport int
win32_putc(int c, FILE *pf)
{
    return putc(c,pf);
}

DllExport int
win32_puts(const char *s)
{
    return puts(s);
}

DllExport int
win32_getchar(void)
{
    return getchar();
}

DllExport int
win32_putchar(int c)
{
    return putchar(c);
}

#ifdef MYMALLOC

#ifndef USE_PERL_SBRK

static char *committed = NULL;
static char *base      = NULL;
static char *reserved  = NULL;
static char *brk       = NULL;
static DWORD pagesize  = 0;
static DWORD allocsize = 0;

void *
sbrk(int need)
{
 void *result;
 if (!pagesize)
  {SYSTEM_INFO info;
   GetSystemInfo(&info);
   /* Pretend page size is larger so we don't perpetually
    * call the OS to commit just one page ...
    */
   pagesize = info.dwPageSize << 3;
   allocsize = info.dwAllocationGranularity;
  }
 /* This scheme fails eventually if request for contiguous
  * block is denied so reserve big blocks - this is only 
  * address space not memory ...
  */
 if (brk+need >= reserved)
  {
   DWORD size = 64*1024*1024;
   char *addr;
   if (committed && reserved && committed < reserved)
    {
     /* Commit last of previous chunk cannot span allocations */
     addr = (char *) VirtualAlloc(committed,reserved-committed,MEM_COMMIT,PAGE_READWRITE);
     if (addr)
      committed = reserved;
    }
   /* Reserve some (more) space 
    * Note this is a little sneaky, 1st call passes NULL as reserved
    * so lets system choose where we start, subsequent calls pass
    * the old end address so ask for a contiguous block
    */
   addr  = (char *) VirtualAlloc(reserved,size,MEM_RESERVE,PAGE_NOACCESS);
   if (addr)
    {
     reserved = addr+size;
     if (!base)
      base = addr;
     if (!committed)
      committed = base;
     if (!brk)
      brk = committed;
    }
   else
    {
     return (void *) -1;
    }
  }
 result = brk;
 brk += need;
 if (brk > committed)
  {
   DWORD size = ((brk-committed + pagesize -1)/pagesize) * pagesize;
   char *addr = (char *) VirtualAlloc(committed,size,MEM_COMMIT,PAGE_READWRITE);
   if (addr)
    {
     committed += size;
    }
   else
    return (void *) -1;
  }
 return result;
}

#endif
#endif

DllExport void*
win32_malloc(size_t size)
{
    return malloc(size);
}

DllExport void*
win32_calloc(size_t numitems, size_t size)
{
    return calloc(numitems,size);
}

DllExport void*
win32_realloc(void *block, size_t size)
{
    return realloc(block,size);
}

DllExport void
win32_free(void *block)
{
    free(block);
}


int
win32_open_osfhandle(long handle, int flags)
{
    return _open_osfhandle(handle, flags);
}

long
win32_get_osfhandle(int fd)
{
    return _get_osfhandle(fd);
}

/*
 * Extras.
 */

static
XS(w32_GetCwd)
{
    dXSARGS;
    SV *sv = sv_newmortal();
    /* Make one call with zero size - return value is required size */
    DWORD len = GetCurrentDirectory((DWORD)0,NULL);
    SvUPGRADE(sv,SVt_PV);
    SvGROW(sv,len);
    SvCUR(sv) = GetCurrentDirectory((DWORD) SvLEN(sv), SvPVX(sv));
    /* 
     * If result != 0 
     *   then it worked, set PV valid, 
     *   else leave it 'undef' 
     */
    if (SvCUR(sv))
	SvPOK_on(sv);
    EXTEND(sp,1);
    ST(0) = sv;
    XSRETURN(1);
}

static
XS(w32_SetCwd)
{
    dXSARGS;
    if (items != 1)
	croak("usage: Win32::SetCurrentDirectory($cwd)");
    if (SetCurrentDirectory(SvPV(ST(0),na)))
	XSRETURN_YES;

    XSRETURN_NO;
}

static
XS(w32_GetNextAvailDrive)
{
    dXSARGS;
    char ix = 'C';
    char root[] = "_:\\";
    while (ix <= 'Z') {
	root[0] = ix++;
	if (GetDriveType(root) == 1) {
	    root[2] = '\0';
	    XSRETURN_PV(root);
	}
    }
    XSRETURN_UNDEF;
}

static
XS(w32_GetLastError)
{
    dXSARGS;
    XSRETURN_IV(GetLastError());
}

static
XS(w32_LoginName)
{
    dXSARGS;
    char *name = getlogin_buffer;
    DWORD size = sizeof(getlogin_buffer);
    if (GetUserName(name,&size)) {
	/* size includes NULL */
	ST(0) = sv_2mortal(newSVpv(name,size-1));
	XSRETURN(1);
    }
    XSRETURN_UNDEF;
}

static
XS(w32_NodeName)
{
    dXSARGS;
    char name[MAX_COMPUTERNAME_LENGTH+1];
    DWORD size = sizeof(name);
    if (GetComputerName(name,&size)) {
	/* size does NOT include NULL :-( */
	ST(0) = sv_2mortal(newSVpv(name,size));
	XSRETURN(1);
    }
    XSRETURN_UNDEF;
}


static
XS(w32_DomainName)
{
    dXSARGS;
    char name[256];
    DWORD size = sizeof(name);
    if (GetUserName(name,&size)) {
	char sid[1024];
	DWORD sidlen = sizeof(sid);
	char dname[256];
	DWORD dnamelen = sizeof(dname);
	SID_NAME_USE snu;
	if (LookupAccountName(NULL, name, &sid, &sidlen,
			      dname, &dnamelen, &snu)) {
	    XSRETURN_PV(dname);		/* all that for this */
	}
    }
    XSRETURN_UNDEF;
}

static
XS(w32_FsType)
{
    dXSARGS;
    char fsname[256];
    DWORD flags, filecomplen;
    if (GetVolumeInformation(NULL, NULL, 0, NULL, &filecomplen,
			 &flags, fsname, sizeof(fsname))) {
	if (GIMME == G_ARRAY) {
	    XPUSHs(sv_2mortal(newSVpv(fsname,0)));
	    XPUSHs(sv_2mortal(newSViv(flags)));
	    XPUSHs(sv_2mortal(newSViv(filecomplen)));
	    PUTBACK;
	    return;
	}
	XSRETURN_PV(fsname);
    }
    XSRETURN_UNDEF;
}

static
XS(w32_GetOSVersion)
{
    dXSARGS;
    OSVERSIONINFO osver;

    osver.dwOSVersionInfoSize = sizeof(OSVERSIONINFO);
    if (GetVersionEx(&osver)) {
	XPUSHs(newSVpv(osver.szCSDVersion, 0));
	XPUSHs(newSViv(osver.dwMajorVersion));
	XPUSHs(newSViv(osver.dwMinorVersion));
	XPUSHs(newSViv(osver.dwBuildNumber));
	XPUSHs(newSViv(osver.dwPlatformId));
	PUTBACK;
	return;
    }
    XSRETURN_UNDEF;
}

static
XS(w32_IsWinNT)
{
    dXSARGS;
    XSRETURN_IV(IsWinNT());
}

static
XS(w32_IsWin95)
{
    dXSARGS;
    XSRETURN_IV(IsWin95());
}

static
XS(w32_FormatMessage)
{
    dXSARGS;
    DWORD source = 0;
    char msgbuf[1024];

    if (items != 1)
	croak("usage: Win32::FormatMessage($errno)");

    if (FormatMessage(FORMAT_MESSAGE_FROM_SYSTEM,
		      &source, SvIV(ST(0)), 0,
		      msgbuf, sizeof(msgbuf)-1, NULL))
	XSRETURN_PV(msgbuf);

    XSRETURN_UNDEF;
}

static
XS(w32_Spawn)
{
    dXSARGS;
    char *cmd, *args;
    PROCESS_INFORMATION stProcInfo;
    STARTUPINFO stStartInfo;
    BOOL bSuccess = FALSE;

    if(items != 3)
	croak("usage: Win32::Spawn($cmdName, $args, $PID)");

    cmd = SvPV(ST(0),na);
    args = SvPV(ST(1), na);

    memset(&stStartInfo, 0, sizeof(stStartInfo));   /* Clear the block */
    stStartInfo.cb = sizeof(stStartInfo);	    /* Set the structure size */
    stStartInfo.dwFlags = STARTF_USESHOWWINDOW;	    /* Enable wShowWindow control */
    stStartInfo.wShowWindow = SW_SHOWMINNOACTIVE;   /* Start min (normal) */

    if(CreateProcess(
		cmd,			/* Image path */
		args,	 		/* Arguments for command line */
		NULL,			/* Default process security */
		NULL,			/* Default thread security */
		FALSE,			/* Must be TRUE to use std handles */
		NORMAL_PRIORITY_CLASS,	/* No special scheduling */
		NULL,			/* Inherit our environment block */
		NULL,			/* Inherit our currrent directory */
		&stStartInfo,		/* -> Startup info */
		&stProcInfo))		/* <- Process info (if OK) */
    {
	CloseHandle(stProcInfo.hThread);/* library source code does this. */
	sv_setiv(ST(2), stProcInfo.dwProcessId);
	bSuccess = TRUE;
    }
    XSRETURN_IV(bSuccess);
}

static
XS(w32_GetTickCount)
{
    dXSARGS;
    XSRETURN_IV(GetTickCount());
}

static
XS(w32_GetShortPathName)
{
    dXSARGS;
    SV *shortpath;
    DWORD len;

    if(items != 1)
	croak("usage: Win32::GetShortPathName($longPathName)");

    shortpath = sv_mortalcopy(ST(0));
    SvUPGRADE(shortpath, SVt_PV);
    /* src == target is allowed */
    do {
	len = GetShortPathName(SvPVX(shortpath),
			       SvPVX(shortpath),
			       SvLEN(shortpath));
    } while (len >= SvLEN(shortpath) && sv_grow(shortpath,len+1));
    if (len) {
	SvCUR_set(shortpath,len);
	ST(0) = shortpath;
    }
    else
	ST(0) = &sv_undef;
    XSRETURN(1);
}

static
XS(w32_Sleep)
{
    dXSARGS;
    if (items != 1)
	croak("usage: Win32::Sleep($milliseconds)");
    Sleep(SvIV(ST(0)));
    XSRETURN_YES;
}

void
Perl_init_os_extras()
{
    char *file = __FILE__;
    dXSUB_SYS;

    /* these names are Activeware compatible */
    newXS("Win32::GetCwd", w32_GetCwd, file);
    newXS("Win32::SetCwd", w32_SetCwd, file);
    newXS("Win32::GetNextAvailDrive", w32_GetNextAvailDrive, file);
    newXS("Win32::GetLastError", w32_GetLastError, file);
    newXS("Win32::LoginName", w32_LoginName, file);
    newXS("Win32::NodeName", w32_NodeName, file);
    newXS("Win32::DomainName", w32_DomainName, file);
    newXS("Win32::FsType", w32_FsType, file);
    newXS("Win32::GetOSVersion", w32_GetOSVersion, file);
    newXS("Win32::IsWinNT", w32_IsWinNT, file);
    newXS("Win32::IsWin95", w32_IsWin95, file);
    newXS("Win32::FormatMessage", w32_FormatMessage, file);
    newXS("Win32::Spawn", w32_Spawn, file);
    newXS("Win32::GetTickCount", w32_GetTickCount, file);
    newXS("Win32::GetShortPathName", w32_GetShortPathName, file);
    newXS("Win32::Sleep", w32_Sleep, file);

    /* XXX Bloat Alert! The following Activeware preloads really
     * ought to be part of Win32::Sys::*, so they're not included
     * here.
     */
    /* LookupAccountName
     * LookupAccountSID
     * InitiateSystemShutdown
     * AbortSystemShutdown
     * ExpandEnvrironmentStrings
     */
}

void
Perl_win32_init(int *argcp, char ***argvp)
{
    /* Disable floating point errors, Perl will trap the ones we
     * care about.  VC++ RTL defaults to switching these off
     * already, but the Borland RTL doesn't.  Since we don't
     * want to be at the vendor's whim on the default, we set
     * it explicitly here.
     */
#if !defined(_ALPHA_) && !defined(__GNUC__)
    _control87(MCW_EM, MCW_EM);
#endif
    MALLOC_INIT; 
}

#ifdef USE_BINMODE_SCRIPTS

void
win32_strip_return(SV *sv)
{
 char *s = SvPVX(sv);
 char *e = s+SvCUR(sv);
 char *d = s;
 while (s < e)
  {
   if (*s == '\r' && s[1] == '\n')
    {
     *d++ = '\n';
     s += 2;
    }
   else 
    {
     *d++ = *s++;
    }   
  }
 SvCUR_set(sv,d-SvPVX(sv)); 
}

#endif
