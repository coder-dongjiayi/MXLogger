//
//  mxlog.cpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#include "mxlog.hpp"
namespace mxlog{
mxlog::mxlog(const char* diskcache_path) : diskcache_path_(diskcache_path){
    printf("log 初始化完成:%s\n",diskcache_path_.c_str());
}

mxlog::~mxlog(){
    printf("log 已经释放\n");
}
}
