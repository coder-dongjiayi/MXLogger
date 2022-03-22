//
//  logger_os.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/16.
//

#ifndef logger_os_hpp
#define logger_os_hpp
#include <stdio.h>
namespace blinglog {
namespace details{
class logger_os{
public:
    static size_t thread_id();
private:
    static size_t thread_id_();
    
};
}
}

#endif /* logger_os_hpp */
