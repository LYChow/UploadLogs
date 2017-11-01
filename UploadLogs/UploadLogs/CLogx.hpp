//
//  CLogx.hpp
//  UploadLogs
//
//  Created by zhouluyao on 10/31/17.
//  Copyright © 2017 zhouluyao. All rights reserved.
//

#ifndef CLogx_hpp
#define CLogx_hpp

#include <stdio.h>
#include <mutex>
#include "sync.h"
#include <thread>

struct CLogx
{
    CLogx();
    ~CLogx();
    void  WriteFile(char *szLog,int nSize ,bool bNeedTrace);
    void  OpenLogFile();
    void  UploadLogs();
    int   UpLoadFileToCenterServerThread();
    int   SendCommandToCenterServer(char * szParam, int nDataLen, char *&RecvBuf, int &RecvLen, int nCommandType);
    char * getFilePath();
protected:
    FILE *m_file;
    int m_uCurSize = 0;
    char *m_szFileName;
    CriticalSection m_cs;
    char *m_mvsIp;
    std::unique_ptr<std::thread> _sendLogThread;
    bool uploadSuccess;
};


#endif /* CLogx_hpp */
