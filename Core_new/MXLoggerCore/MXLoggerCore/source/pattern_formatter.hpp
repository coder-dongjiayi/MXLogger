//
//  pattern_formatter.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#ifndef pattern_formatter_hpp
#define pattern_formatter_hpp

#include <stdio.h>
#include <string>
#include "log_msg.hpp"
#include "flag_formatter.hpp"
#include <vector>
namespace mxlogger {

class pattern_formatter {
    
public:
    pattern_formatter(const std::string &pattern);
    ~pattern_formatter(){
        printf("pattern_formatter 释放\n");
    };
    void format(const details::log_msg &msg, string &dest);
private:
    std::string pattern_;
    
    void compile_pattern_(const std::string pattern);
    void handle_flag_(char flag);
    
    
    std::vector<std::unique_ptr<details::flag_formatter>> formatters_;
};

};


#endif /* pattern_formatter_hpp */
