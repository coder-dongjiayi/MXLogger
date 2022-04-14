//
//  console_sink.hpp
//  MXLoggerCore
//
//  Created by 董家祎 on 2022/4/13.
//

#ifndef console_sink_hpp
#define console_sink_hpp

#include <stdio.h>
#include "sink.hpp"
namespace mxlogger{

namespace sinks {
class console_sink : public sink{
public:
    console_sink(FILE *target_file);
    
    ~console_sink() override = default;
    
    void log(const details::log_msg &msg) override;
    
    void set_pattern(const std::string &pattern) final;
    
    void flush() override;
private:
    FILE *target_file_;
    
};


};

};


#endif /* console_sink_hpp */
