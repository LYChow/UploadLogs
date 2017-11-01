#pragma once

#ifndef _SYNC_H_
#define _SYNC_H_

#ifdef WIN32



#include <windows.h>

class CriticalSection
{
public:
    CriticalSection ( ) 
    { 
        InitializeCriticalSection ( &m_CritSec );
    }
#if (_WIN32_WINNT >= 0x0403)
    CriticalSection ( LONG spinCount )
    {
        InitializeCriticalSectionAndSpinCount ( &m_CritSec, spinCount );
    }
#endif
    ~CriticalSection ( ) 
    { 
        DeleteCriticalSection ( &m_CritSec );
    }
    void Acquire ( ) 
    { 
        EnterCriticalSection ( &m_CritSec ); 
    }
    void Release ( ) 
    { 
        LeaveCriticalSection ( &m_CritSec ); 
    }
private:
    CriticalSection ( const CriticalSection& c );
    CriticalSection& operator= ( const CriticalSection& c );
    CRITICAL_SECTION m_CritSec;
};



#else // #ifdef WIN32



//#ifdef DEBUG
//#ifndef _DEBUG
//#define _DEBUG
//#endif // #ifndef _DEBUG
//#endif // #ifdef DEBUG

#include <pthread.h>
#include <stdio.h>
class CriticalSection
{
public:
    CriticalSection() {
        pthread_mutexattr_t mutexAttr;
        ir = pthread_mutexattr_init(&mutexAttr);
        ir = pthread_mutexattr_setpshared(&mutexAttr, PTHREAD_PROCESS_PRIVATE);
        ir = pthread_mutexattr_settype(&mutexAttr, PTHREAD_MUTEX_RECURSIVE);
        ir = pthread_mutex_init(&m_thread_mutex, &mutexAttr);
    }
    ~CriticalSection() {
        ir = pthread_mutex_destroy(&m_thread_mutex);
    }
    void Acquire() {
        ir = pthread_mutex_lock(&m_thread_mutex);
    }
    void Release() {
        ir = pthread_mutex_unlock(&m_thread_mutex);
    }
private:
    CriticalSection(const CriticalSection& c);
    CriticalSection& operator=(const CriticalSection& c);
    pthread_mutex_t m_thread_mutex;
    int ir = 0;
};



#endif // #ifdef WIN32



template <class T>
class SyncLock
{
public:
    SyncLock ( T& obj ) 
        : m_SyncObject ( obj )
    { 
		//long lret =InterlockedIncrement(&g_nIndex);
		//		printf("### SyncLock() =%d \n", lret);

#ifdef _DEBUG
		DWORD ticbeforelock = GetTickCount();
#endif // _DEBUG
        m_SyncObject.Acquire ( );
#ifdef _DEBUG
		ticlock = GetTickCount();
		DWORD costtic = ticlock-ticbeforelock;
		if (costtic > 1000)
		{
			TRACE("{tid: %d}SyncLock! cost %d ms.\n", GetCurrentThreadId(), costtic);
			if (costtic > 10*1000)
			{
				TRACE("{tid: %d}SyncLock! Long cost %d ms.\n", GetCurrentThreadId(), costtic);
			}
		}
#endif // _DEBUG
    }

    ~SyncLock()
    {
		//long lret =InterlockedDecrement(&g_nIndex);
		
		//printf("### ~SyncLock() =%d \n", lret);
        m_SyncObject.Release ( );
#ifdef _DEBUG
		DWORD locklength = GetTickCount()-ticlock;
		if (locklength > 1000)
		{
			TRACE("{tid: %d}SyncLock over! locklength %d ms.\n", GetCurrentThreadId(), locklength);
			if (locklength > 10*1000)
			{
				TRACE("{tid: %d}SyncLock over. long lock! %d ms.\n", GetCurrentThreadId(), locklength);
			}
		}
#endif // _DEBUG
    }

private:
    T&  m_SyncObject;
#ifdef _DEBUG
	DWORD ticlock;
#endif // _DEBUG
};

typedef SyncLock<CriticalSection> CriticalSectionLock;

#endif // _SYNC_H_
