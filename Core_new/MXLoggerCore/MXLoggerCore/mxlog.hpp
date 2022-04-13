//
//  mxlog.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#ifndef mxlog_hpp
#define mxlog_hpp
#include <string>
#include <stdio.h>
namespace mxlog{

class mxlog{
    
public:
    mxlog(const char *diskcache_path);
    ~mxlog();
private:
    std::string diskcache_path_;
};


}


#endif /* mxlog_hpp */
