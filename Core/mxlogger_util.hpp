//
//  mxlogger_util.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/7.
//

#ifndef mxlogger_util_hpp
#define mxlogger_util_hpp

#include <stdio.h>
#include <vector>
#include <map>
namespace mxlogger{
namespace util{

class mxlogger_util{
    
public:
    static long select_log_form_path(const char* path,std::vector<std::string> *destination);
    

    static int select_logfiles_dir(const char* dir,std::vector<std::map<std::string, std::string>> *destination);
};

 

};

}




#endif /* mxlogger_util_hpp */
