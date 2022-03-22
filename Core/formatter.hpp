//
//  formatter.hpp
//  Logger
//
//  Created by 董家祎 on 2022/2/26.
//

#ifndef formatter_hpp
#define formatter_hpp
#include "log_msg.h"
#include <stdio.h>
namespace blinglog{

class formatter{
private:
    std::tm localtime_(const std::time_t &time_tt);
    
    std::string eol_;
    
    
public:
     formatter();
    virtual void format(const details::log_msg &msg, memory_buf_t &dest) = 0;
    virtual ~formatter() = default;
    
   
};


}


#endif /* formatter_hpp */
