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
#include "file_appender.hpp"
namespace mxlogger{
namespace sinks {

class file_sink : public sink{
public:
    file_sink(std::shared_ptr<details::mx_file> file): mxfile(file) {};
    
    ~file_sink(){
        printf("file_sink 释放\n");
    };
    
    void log(const details::log_msg &msg) override;
    
    void set_pattern(const std::string &pattern) final;
    
    void flush() override;
    
    std::shared_ptr<details::mx_file> mxfile;
    
private:
    
    details::file_appender file_appender_;
};

};
};
#endif /* file_sink_hpp */
