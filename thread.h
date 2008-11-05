/*    thread.h
 *
 *    Copyright (C) 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006,
 *    by Larry Wall and others
 *
 *    You may distribute under the terms of either the GNU General Public
 *    License or the Artistic License, as specified in the README file.
 *
 */

#ifndef MUTEX_LOCK
#  define MUTEX_LOCK(m)
#endif

#ifndef MUTEX_UNLOCK
#  define MUTEX_UNLOCK(m)
#endif

#ifndef MUTEX_INIT
#  define MUTEX_INIT(m)
#endif

#ifndef MUTEX_DESTROY
#  define MUTEX_DESTROY(m)
#endif

#ifndef COND_INIT
#  define COND_INIT(c)
#endif

#ifndef COND_SIGNAL
#  define COND_SIGNAL(c)
#endif

#ifndef COND_BROADCAST
#  define COND_BROADCAST(c)
#endif

#ifndef COND_WAIT
#  define COND_WAIT(c, m)
#endif

#ifndef COND_DESTROY
#  define COND_DESTROY(c)
#endif

#ifndef LOCK_SV_MUTEX
#  define LOCK_SV_MUTEX
#endif

#ifndef UNLOCK_SV_MUTEX
#  define UNLOCK_SV_MUTEX
#endif

#ifndef LOCK_STRTAB_MUTEX
#  define LOCK_STRTAB_MUTEX
#endif

#ifndef UNLOCK_STRTAB_MUTEX
#  define UNLOCK_STRTAB_MUTEX
#endif

#ifndef LOCK_CRED_MUTEX
#  define LOCK_CRED_MUTEX
#endif

#ifndef UNLOCK_CRED_MUTEX
#  define UNLOCK_CRED_MUTEX
#endif

#ifndef LOCK_FDPID_MUTEX
#  define LOCK_FDPID_MUTEX
#endif

#ifndef UNLOCK_FDPID_MUTEX
#  define UNLOCK_FDPID_MUTEX
#endif

#ifndef LOCK_SV_LOCK_MUTEX
#  define LOCK_SV_LOCK_MUTEX
#endif

#ifndef UNLOCK_SV_LOCK_MUTEX
#  define UNLOCK_SV_LOCK_MUTEX
#endif

#ifndef LOCK_DOLLARZERO_MUTEX
#  define LOCK_DOLLARZERO_MUTEX
#endif

#ifndef UNLOCK_DOLLARZERO_MUTEX
#  define UNLOCK_DOLLARZERO_MUTEX
#endif

/* THR, SET_THR, and dTHR are there for compatibility with old versions */
#ifndef THR
#  define THR		PERL_GET_THX
#endif

#ifndef SET_THR
#  define SET_THR(t)	PERL_SET_THX(t)
#endif

#ifndef dTHR
#  define dTHR dNOOP
#endif

#ifndef INIT_THREADS
#  define INIT_THREADS NOOP
#endif

/*
 * Local variables:
 * c-indentation-style: bsd
 * c-basic-offset: 4
 * indent-tabs-mode: t
 * End:
 *
 * ex: set ts=8 sts=4 sw=4 noet:
 */
