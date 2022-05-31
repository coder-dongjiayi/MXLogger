//
//  file_sink.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/14.
//

#ifndef file_sink_hpp
#define file_sink_hpp

#include <stdio.h>
#include "sink.hpp"
#include "mx_file.hpp"

namespace mxlogger{
namespace sinks {

class file_sink : public sink{
public:
    file_sink(std::shared_ptr<details::mx_file> file): mxfile(file) {
        filename_ = "mxlog";
        handle_date(policy::storage_policy::yyyy_MM_dd);
    };
    
    ~file_sink(){};
    
    void log(const details::log_msg &msg) override;
        
    void flush() override;
    
    void set_policy(policy::storage_policy policy);
    void set_filename(const std::string filename);
    
    std::shared_ptr<details::mx_file> mxfile;
    
private:
    std::string calculator_filename_;

};

};
};
#endif /* file_sink_hpp */
