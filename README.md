# UploadLogs
用C++语言实现本地调试信息通过socket用TCP协议往服务器的上传

以下是我公司往服务器写文件时定义的协议,demo不具有通用性,可以参考demo中实现的思路

上传文件

1) 新建文件
//请求
Sender=Jim
Type=FileAccess
Cmd=NewFile
ID=
FullName=/vc3/Config.ini
Size=1342814

//应答
Sender=Jim
Type=FileAccess
Cmd=NewFile
ID=
FullName=/vc3/Config.ini
Error=0


2) 分块上传文件
//请求
Sender=Jim
Type=FileAccess
Cmd=WriteFile
ID=
FullName=/vc3/Config.ini
Offset=0
ContentSize=1024\r\n\r\n
[BinaryData]

//应答
Sender=Jim
Type=FileAccess
Cmd=WriteFile
ID=
FullName=/vc3/Config.ini
Offset=0
Error=0


3) 关闭文件
//请求
Sender=Jim
Type=FileAccess
Cmd=CloseFile
ID=
FullName=/vc3/Config.ini

//应答
Sender=Jim
Type=FileAccess
Cmd=CloseFile
ID=
FullName=/vc3/Config.ini
Error=0
