//
//  CLogx.cpp
//  UploadLogs
//
//  Created by zhouluyao on 10/31/17.
//  Copyright © 2017 zhouluyao. All rights reserved.
//

#include "CLogx.hpp"
#include <netinet/tcp.h>
#include <sys/stat.h>
#include <iostream>
#include <fstream>
#include <sys/socket.h>
#import <arpa/inet.h>
#import <fcntl.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <netinet/in.h>
#import <net/if.h>
#import <sys/socket.h>
#import <sys/types.h>
#import <sys/ioctl.h>
#import <sys/poll.h>
#import <sys/uio.h>
#import <sys/un.h>
#import <unistd.h>
#import <string.h>

#define m_uMaxSize 1024*1024*32
typedef unsigned int DWORD,*LPDWORD;
typedef unsigned short WORD,*LPWORD;
#define closesocket close
#import <Foundation/Foundation.h>






typedef struct tagSWVC3CenterServerCmd
{
    
    DWORD dwSize;    //整个指令长度
    
    WORD  wCmdCode;    //指令码
    
    WORD  wSeqNo;   //命令序号
    
    tagSWVC3CenterServerCmd() { Reset(); }
    
    void Reset(void) { memset(this, 0x00, sizeof(*this)); }
    
    void SetSize(int nCmdLen) { dwSize = sizeof(*this) + nCmdLen; }
    
    int  GetSize(void) const { return dwSize - sizeof(*this); }
    
}SWVC3CenterServerCmd, *pSWVC3CenterServerCmd;



CLogx::CLogx()
{
    m_mvsIp = "123.57.69.16";
    m_file = NULL;
    m_szFileName=0;
    OpenLogFile();
}

int GetDocumentDirectory(char* buf, int bufsize)
{
    if (!bufsize || bufsize<1) {
        return -1;
    }
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    if (!paths) {
        return -1;
    }
    NSString *docDir = [paths objectAtIndex:0];
    if (!docDir) {
        return -1;
    }
    
    int ir = [docDir length];
    if (ir >= bufsize) {
        ir = bufsize-1;
    }
    strncpy(buf, [docDir UTF8String], ir);
    
    return ir;
}

char * CLogx::getFilePath()
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = [paths objectAtIndex:0];
    NSString *filePath = [NSString stringWithFormat:@"%@/SW_UVCTeminal_Log.txt",docDir];
    //    NSString *filePath = [[NSBundle mainBundle]pathForResource:@"how_to_read_a_book" ofType:@".txt"];
    char sz_buffer[1000];
    
    strcpy(sz_buffer, (char *)[filePath UTF8String]);
    char *sz_filePath;
    sz_filePath = sz_buffer;
    return sz_filePath;
}

char * CLogx::getUploadProcess()
{
    if (uploadProcess)
    {
        return uploadProcess;
    }
    return 0;
}

void CLogx::WriteFile(char *szLog,int nSize ,bool bNeedTrace)
{
    CriticalSectionLock l(m_cs);
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    //设定时间格式,这里可以设置成自己需要的格式
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    //用[NSDate date]可以获取系统当前时间
    NSString *currentDateStr = [dateFormatter stringFromDate:[NSDate date]];
    NSStringEncoding enc = CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingDOSChineseSimplif);
    const char *dateChar = [currentDateStr cStringUsingEncoding:enc];
    
    char sz_formatLog[512] = {0};
    strncpy(sz_formatLog, dateChar, strlen(dateChar));
    strncpy(sz_formatLog + strlen(dateChar) , szLog, strlen(szLog));
    //写文件
    try
    {
        if (m_file)
        {
            fwrite(sz_formatLog, strlen(sz_formatLog), 1, m_file);
            fflush(m_file);
            m_uCurSize += strlen(sz_formatLog);
            
            //如果日志大小超过了设定值,删除日志
            if (m_uCurSize>=m_uMaxSize)
            {
                fclose(m_file);
                remove(m_szFileName);
                m_uCurSize = 0;
                
                //重新打开文件
                OpenLogFile();
            }
        }
    } catch (...)
    {
        
    }
    
    if (bNeedTrace)
    {
        printf("szLog = %s size=%d",sz_formatLog,nSize);
    }
}

void CLogx::OpenLogFile()
{
    
    char szBuf[512] = {0};
    int ir = GetDocumentDirectory(szBuf, sizeof(szBuf)-1);
    if (ir > 0)
    {
        snprintf(szBuf+ir, sizeof(szBuf)-ir-1, "/SW_UVCTeminal_Log.txt");  //返回值为写入的字节数,返回值为负数时出错,待写入的字符串大于剩余长度(size)时,能拷多少拷多少‘\0’结尾,超出内容忽略
        m_szFileName = szBuf;
        m_file = fopen(m_szFileName, "a");
        if (m_file)
        {
            const char * szLog ="\r\n";
            fwrite(szLog, strlen(szLog), 1, m_file);
            fflush(m_file);
        }
    }
}


int CLogx::SendCommandToCenterServer(char * szParam, int nDataLen, char *&RecvBuf, int &RecvLen, int nCommandType)
{
    //未配置中心服务器
    if (strlen(m_mvsIp) == 0 || 0 == strcmp(m_mvsIp, "0.0.0.0") || 0 == strcmp(m_mvsIp, "255.255.255.255"))
        //|| 0 == strlen(szParam) || strlen(szParam) > 8*1024*1024)
    {
        NSLog(@"未配置中心服务器!");
        return -1;
    }
    
    int nSrcLen = nDataLen > 0?nDataLen:strlen(szParam) + 1;
    if (nSrcLen <= 0 || nSrcLen > 8*1024*1024)
    {
        NSLog(@"Send to centerserver datalen = %d", nSrcLen);
        return -1;
    }
    
    if (nCommandType < 2)
    {
        if (strlen(szParam) < 256)
        {
            NSLog(@"向中心服务器发送命令: %s", szParam);
        }
        NSLog(@"向中心服务器发送命令长度 = %d", nSrcLen);
    }
    
    int sock = socket( AF_INET, SOCK_STREAM, 0);
    if (sock == -1)
    {
        NSLog(@"向中心服务器发送命令，创建socket失败!");
        return -2;
    }
    
    bool abs = TRUE;
    int optionLen = sizeof(abs), timeout = 5000;
    setsockopt(sock,IPPROTO_TCP,TCP_NODELAY,(char *)&abs,optionLen);
    setsockopt(sock,SOL_SOCKET,SO_RCVTIMEO,(char *)&timeout,optionLen);
    setsockopt(sock,SOL_SOCKET,SO_SNDTIMEO,(char *)&timeout,optionLen);
    
    //连接服务器
    
    
    
    sockaddr_in dest_sin;
    dest_sin.sin_family = AF_INET;
    dest_sin.sin_port = htons(264);
    dest_sin.sin_addr.s_addr = inet_addr(m_mvsIp);
    
    
    int ret = connect(sock,(struct sockaddr*)&dest_sin,sizeof(dest_sin));
    int socketConnnectErr=errno;
    if(ret != 0 )
    {
        if(errno == EISCONN)
        {
           NSLog(@"connect socket completed");
        }
        if(errno != EINPROGRESS && errno != EALREADY && errno != EWOULDBLOCK)
        {
            NSLog(@"connect socket failed");
        }
        else
        {
            NSLog(@"connect socket does not completed");
        }
        
        
        NSLog(@"connect 中心服务器失败! ret=%d  error=%d",ret,socketConnnectErr); //socketConnnectErr =errno.61 is: No data available
        closesocket( sock );
        return -3;
    }

    
    int nCmdLen = nSrcLen + 256;
    char *pCmdBuf = new char[nCmdLen];
    memset(pCmdBuf, 0x00, nCmdLen);
    
    const int CMD_NEWCMDMODE = 2;
    const int SENDTO_DATACENTER_LEN = 1024;
    static WORD wSendCenterServerCmdSeq = 0;
    pSWVC3CenterServerCmd pSendCmd = (pSWVC3CenterServerCmd)pCmdBuf;
    pSendCmd->Reset();
    pSendCmd->SetSize(nSrcLen);
    pSendCmd->wCmdCode = CMD_NEWCMDMODE;
    pSendCmd->wSeqNo = wSendCenterServerCmdSeq++;
    //    strcpy(pCmdBuf + sizeof(SWVC3CenterServerCmd), szParam);
    memcpy(pCmdBuf + sizeof(SWVC3CenterServerCmd), szParam, nSrcLen);
    
    char *pSendBuf = pCmdBuf;
    int nSendLenLeft = pSendCmd->dwSize;
    do
    {
        int nCurSendLen = nSendLenLeft > SENDTO_DATACENTER_LEN? SENDTO_DATACENTER_LEN: nSendLenLeft;
        //发送请求
        if(send(sock, pSendBuf, nCurSendLen, 0) == -1)
        {
            closesocket(sock);
            delete []pCmdBuf;
            NSLog(@"向中心服务器发送数据失败");
            return -4;
        }
        pSendBuf += nCurSendLen;
        nSendLenLeft -= nCurSendLen;
        
        //            sleep(1);
    } while (nSendLenLeft > 0);
    
    
    //接收
    SWVC3CenterServerCmd RecvCmd;
    char *pRecv = (char *)&RecvCmd;
    for (int i = 0; i < sizeof(RecvCmd); i++)
    {
        int status = recv(sock, pRecv, 1, 0);
        int err=errno;
        if( status == -1 )
        {
             NSLog(@"[SendCommandToCenterServer]: recv error=%d", err);
            closesocket( sock );
            return -5;
        }
        else if(status == 0)
        {
            break;
        }
        else
        {
            pRecv++;
        }
    }
    
    DWORD dwTotalLen = RecvCmd.GetSize();
    DWORD dwRecvLenLeft = dwTotalLen;
    if (nCommandType < 2)
    {
         NSLog(@"开始接收中心服务器数据长度 = %d", dwRecvLenLeft);
    }
    if (dwRecvLenLeft > 32*1024*1024 || dwRecvLenLeft == 0)
    {
        closesocket(sock);
        return -6;
    }
    
    int nRecvBufLen = ((dwRecvLenLeft>>10) + 1)<<10;
    char *pRecvBuf = new char[nRecvBufLen];
    memset(pRecvBuf, 0x00, nRecvBufLen);
    pRecv = pRecvBuf;
    
    do
    {
        
        int status = recv(sock, pRecv, 1, 0);
        int err=errno;
        if( status == -1 )
        {
            NSLog(@"接收中心服务器数据 error=%d", err);
            closesocket( sock );
            delete []pRecvBuf;
            return -7;
        }
        else if( status == 0 )
        {
            break;
        }
        else
        {
            pRecv++;
            dwRecvLenLeft--;
        }
    } while( dwRecvLenLeft > 0 );
    
    return 0;
}

void CLogx::UploadLogs()
{
    if (uploadSuccess)
    {
        if(_sendLogThread && _sendLogThread->joinable())
        {
            _sendLogThread->join();
            _sendLogThread.reset();
        }
    }
    if (!_sendLogThread)
    {
    _sendLogThread.reset(new std::thread(&CLogx::UpLoadFileToCenterServerThread, this));
    }
}

int CLogx::UpLoadFileToCenterServerThread()
{
    const int CENTER_SEVER_UP_DATABUF_LEN = 1024;
    do
    {
        int nRet = 0;
        char *pRecvBuf = NULL;
        int nRecvLen = 0;
        
        
        char sMsgHead[512] = {0};
        sprintf(sMsgHead, "Sender=\r\nType=FileAccess\r\nCmd=NewFile\r\nID=\r\nFullName=/vc3/%s.txt\r\n","github");
        
        
        nRet = SendCommandToCenterServer(sMsgHead, strlen(sMsgHead) + 1, pRecvBuf, nRecvLen, 2);
        if (nRet < 0)
        {
            char szLog1[512] = {0};
            sprintf(szLog1, "发送新建文件指令失败 ret=%d \n",nRet);
            WriteFile(szLog1,(int)strlen(szLog1), 1);
            break;
        }
        
        char filePath[512] ={0};
        strcpy(filePath, getFilePath());
        
        if (strlen(filePath)<1)
        {
            NSLog(@"获取不到本地log文件");
            break;
        }
        DWORD dwFileLen = -1;
        
        //读取本地的.txt文件
        std::ifstream is(filePath,std::ifstream::binary);
        if (!is)
        {
            char szLog2[512] = {0};
            sprintf(szLog2, "打开本地文件失败 error = %s,filePath = %s \n",strerror(errno),filePath);
            WriteFile(szLog2,(int)strlen(szLog2), 1);
            return 0;
        }
        is.seekg(0, is.end);
        dwFileLen = (DWORD)is.tellg();
        is.seekg (0, is.beg);
        
        char szLog3[512] = {0};
        sprintf(szLog3, "打开本地文件成功 文件的长度=%d \n",dwFileLen);
        WriteFile(szLog3,(int)strlen(szLog3), 1);
        
        int nBufLen = dwFileLen > CENTER_SEVER_UP_DATABUF_LEN? CENTER_SEVER_UP_DATABUF_LEN : dwFileLen;
        char *pFileBuf = new char[nBufLen + 512];
        DWORD dwFileLenLeft = dwFileLen;
        int nCurRepack = 0;  //当前包编号
        int nTotalRepack = dwFileLen/CENTER_SEVER_UP_DATABUF_LEN + 1; //总共可拆分的包数
        while (dwFileLenLeft > 0)
        {
            int nReadLeftLen = dwFileLenLeft > CENTER_SEVER_UP_DATABUF_LEN? CENTER_SEVER_UP_DATABUF_LEN: dwFileLenLeft;  //剩余的长度,大于512K按照512K
            char sMsgHead[512] = {0};
            int n_offSet = dwFileLen - dwFileLenLeft;
            sprintf(sMsgHead, "Sender=\r\nType=FileAccess\r\nCmd=WriteFile\r\nID=\r\nFullName=/vc3/%s.txt\r\nOffset=%d\r\nContentSize=%d\r\n\r\n",
                    "github", n_offSet, nReadLeftLen);
            memcpy(pFileBuf, sMsgHead, strlen(sMsgHead));
            //                int nReadLen = pSendFile->Read(pFileBuf + strlen(sMsgHead), nReadLeftLen); 暂不分段上传
            
            
            
            //把读指针移动到指定的位置
            is.seekg (n_offSet, std::ios::beg);
            // allocate memory:
            char * inFileBuf = new char [nReadLeftLen];
            
            // read data as a block:
            
            is.read(inFileBuf,nReadLeftLen);
            
            memcpy(pFileBuf + strlen(sMsgHead), inFileBuf, nReadLeftLen);
            
            delete [] inFileBuf;
            
            int nSendLen = nReadLeftLen + strlen(sMsgHead);
            NSLog(@"pFileBuf = %s  len = %d",pFileBuf,nSendLen);
            nRet = SendCommandToCenterServer(pFileBuf, nSendLen, pRecvBuf, nRecvLen, 2);
            if (nRet == -7 || nRet == -9)
            {
                nRet = SendCommandToCenterServer(pFileBuf, nSendLen, pRecvBuf, nRecvLen, 2);
                if (nRet == -7 || nRet == -9)
                {
                    nRet = SendCommandToCenterServer(pFileBuf, nSendLen, pRecvBuf, nRecvLen, 2);
                }
            }
            if (nRet < 0)
            {
                char szLog5[512] = {0};
                sprintf(szLog5, "向服务器写文件失败 ret = %d \n",nRet);
                WriteFile(szLog5,(int)strlen(szLog5), 1);
                
                break;
            }
            dwFileLenLeft -= nReadLeftLen;
            nCurRepack++;
            
            NSLog(@"上传进度:%.2f %@ \n",nCurRepack/(float)nTotalRepack*100,@"%");
            uploadProcess = (char *)[[NSString stringWithFormat:@"上传进度:%.2f%@ \n",nCurRepack/(float)nTotalRepack*100,@"%"] cStringUsingEncoding:NSUTF8StringEncoding];

            m_ProcessCallback(uploadProcess);
        }
        if (nRet < 0)
        {
            break;
        }
        is.close();
        memset(sMsgHead, 0x00, sizeof(sMsgHead));
        sprintf(sMsgHead, "Sender=\r\nType=FileAccess\r\nCmd=CloseFile\r\nID=\r\nFullName=/vc3/%s.txt\r\n", "github");
        nRet = SendCommandToCenterServer(sMsgHead, strlen(sMsgHead) + 1, pRecvBuf, nRecvLen, 2);
        
        uploadSuccess =YES;

        
    }while (FALSE);
    return 0;
}

CLogx::~CLogx()
{
    if (m_file) {
        fclose(m_file);
        m_file = NULL;
    }
}
