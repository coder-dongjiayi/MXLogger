//
//  file_appender.hpp
//  Logger
//
//  Created by 董家祎 on 2022/3/9.
//

#ifndef file_appender_hpp
#define file_appender_hpp
#include "log_enum.h"
#include <string>

namespace mxlogger{
namespace details{
class file_appender {
 
public:
     file_appender();
    ~file_appender();
    void set_policy(policy::storage_policy policy);
    void set_filename(const std::string filename);
   
    std::string calc_filename();
private:
    void handle_date_(policy::storage_policy policy);
     policy::storage_policy policy_;
     std::string filename_;
    
     std::string calculator_filename_;
};
}
}
#endif /* file_appender_hpp */
