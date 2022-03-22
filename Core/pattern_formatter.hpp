//
//  pattern_formatter.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/2.
//

#ifndef pattern_formatter_hpp
#define pattern_formatter_hpp
#include "fmt_helper.h"
#include "formatter.hpp"
#include "flag_formatter.hpp"
#include <vector>
namespace blinglog{
class pattern_formatter final : public  formatter{
    
public:
    explicit pattern_formatter(std::string pattern);
    pattern_formatter();
    
    void format(const details::log_msg &msg, memory_buf_t &dest) override;
    
private:
    void compile_pattern_(const std::string pattern);
    void handle_flag_(char flag);
    std::tm  localtime_(const std::time_t &time_tt);
    std::string pattern_;
    std::vector<std::unique_ptr<details::flag_formatter>> formatters_;
};

};

#endif /* pattern_formatter_hpp */
