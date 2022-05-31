//
//  constructor_json.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/5/31.
//

#ifndef constructor_json_hpp
#define constructor_json_hpp

#include <stdio.h>
#include <string>
namespace mxlogger{
class constructor_json{
    
public:
    
    static std::string to_json(const char* name,const char* tag,const char* msg,bool  is_main_thread,int level);
};
};

#endif /* constructor_json_hpp */
